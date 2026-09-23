#!/usr/bin/env python3
"""Master a CONTINUOUS recording with a smoothly ridden gain curve.

Per-track normalisation steps at every join (measured: up to +6.67 dB between
movements of jam-20260923-1403). One album-wide gain removes the steps but
freezes mistakes in the live mix (in that take the later sections needed +20 dB).

The right treatment for one continuous programme is in between: measure each
section, give each its own gain, and interpolate the gain across the section
boundaries so the level drifts instead of jumping. That is what a mastering
engineer does with a fader on a live mix — no steps, no frozen imbalance.

Implementation: measure loudness per section (through the same high-pass +
compression chain that the render uses), then write a piecewise-linear gain
curve anchored at section midpoints and apply it with ffmpeg's
`volume=eval=frame` expression, followed by the true-peak limiter.

Usage:
  tools/master_smooth.py recordings/jam-*.flac --cues cues.txt --target -14 \
      --ramp 20 --out albums/<album>/mastered-smooth [--mp3]
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import master as M  # noqa: E402  (reuse measure / comp_filter / PRESETS)

TP_MARGIN = M.TP_MARGIN


def parse_cues(path: pathlib.Path):
    cues = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"(\d+):(\d+(?:\.\d+)?)\s+(\d+):(\d+(?:\.\d+)?)\s+(.+)", line)
        if not m:
            raise SystemExit(f"bad cue line: {line}")
        a = int(m.group(1)) * 60 + float(m.group(2))
        b = int(m.group(3)) * 60 + float(m.group(4))
        cues.append((a, b, m.group(5).strip()))
    return cues


def gain_curve_expr(anchors: list[tuple[float, float]]) -> str:
    """Piecewise-linear gain in dB as an ffmpeg volume expression (t = seconds).

    `volume=eval=frame` evaluates per frame; the expression below is a nested
    if() chain with linear interpolation between anchors.
    """
    def lin(t0, g0, t1, g1):
        return f"({g0:.4f}+({g1 - g0:.4f})*(t-{t0:.3f})/({t1 - t0:.3f}))"

    expr = f"{anchors[-1][1]:.4f}"          # after the last anchor: hold
    for i in range(len(anchors) - 1, 0, -1):
        t0, g0 = anchors[i - 1]
        t1, g1 = anchors[i]
        expr = f"if(lt(t,{t1:.3f}),{lin(t0, g0, t1, g1)},{expr})"
    t0, g0 = anchors[0]
    expr = f"if(lt(t,{t0:.3f}),{g0:.4f},{expr})"   # before the first anchor: hold
    # ffmpeg's volume filter evaluates to a LINEAR multiplier, and the 'dB'
    # suffix is only valid on a constant (parsed once at init), never on an
    # expression. So convert the dB curve to linear inside the expression.
    return f"pow(10,({expr})/20)"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("recording")
    ap.add_argument("--cues", required=True)
    ap.add_argument("--target", type=float, default=-14.0)
    ap.add_argument("--tp", type=float, default=-1.0)
    ap.add_argument("--lra", type=float, default=11.0)
    ap.add_argument("--ramp", type=float, default=20.0,
                    help="seconds of glide between section levels")
    ap.add_argument("--preset", default="share", choices=sorted(M.PRESETS))
    ap.add_argument("--comp", default=None,
                    choices=["none", "light", "medium", "heavy"])
    ap.add_argument("--hpf", type=float, default=30.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mp3", action="store_true")
    ap.add_argument("--bits", type=int, default=24, choices=[16, 24])
    a = ap.parse_args()

    src = pathlib.Path(a.recording).expanduser().resolve()
    outdir = pathlib.Path(a.out).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)
    cues = parse_cues(pathlib.Path(a.cues))
    total = M.duration(src) if hasattr(M, "duration") else float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(src)], capture_output=True, text=True,
        check=True).stdout.strip())

    target, comp, softclip = M.PRESETS[a.preset]
    if a.comp:
        comp = a.comp
    pre: list[str] = []
    if a.hpf > 0:
        pre.append(f"highpass=f={a.hpf}")
    pre += M.comp_filter(comp)

    # measure each section (through the same pre-chain the render will use)
    work = outdir / "_sections"
    work.mkdir(parents=True, exist_ok=True)
    rows = []
    for i, (s, e, title) in enumerate(cues, 1):
        seg = work / f"{i:02d}.flac"
        M.run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-ss", f"{s:.3f}",
               "-i", str(src), "-t", f"{e - s:.3f}", "-c:a", "flac", str(seg)])
        st = M.measure(seg, target, a.tp, a.lra, pre)
        lufs = float(st["input_i"])
        rows.append({"section": i, "title": title, "start": s, "end": e,
                     "lufs": lufs, "gain_db": round(target - lufs, 2),
                     "tp": float(st["input_tp"])})
        print(f"  {i:02d} {title[:34]:36s} {lufs:7.2f} LUFS -> gain {rows[-1]['gain_db']:+6.2f} dB")

    # anchors: midpoint of each section, glided over `ramp` seconds around boundaries
    anchors: list[tuple[float, float]] = []
    for r in rows:
        anchors.append(((r["start"] + r["end"]) / 2.0, r["gain_db"]))
    # clamp the glide: no more than ±1 dB per `ramp/2` seconds of travel
    max_step = a.ramp / 2.0 / 4.0          # ≈0.25 dB per second at ramp=20
    for i in range(1, len(anchors)):
        t0, g0 = anchors[i - 1]
        t1, g1 = anchors[i]
        allowed = max_step * max(t1 - t0, 1.0)
        if abs(g1 - g0) > allowed:
            g1 = g0 + allowed * (1 if g1 > g0 else -1)
            anchors[i] = (t1, g1)
            rows[i]["gain_db"] = round(g1, 2)

    expr = gain_curve_expr(anchors)
    # ffmpeg's volume filter treats a bare expression as a LINEAR multiplier;
    # the curve is in dB, so it must be suffixed. (Bare values applied as
    # x1.47..x16.89 produced a master 4 dB over target with positive true peaks.)
    chain = list(pre) + [f"volume=eval=frame:volume='{expr}'"]
    if softclip:
        chain.append("asoftclip=type=tanh:threshold=-3dB")
    chain.append(f"alimiter=limit={10 ** ((a.tp - TP_MARGIN) / 20.0):.4f}:level=disabled")

    master = outdir / f"{src.stem}.smooth.flac"
    cmd = ["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(src),
           "-af", ",".join(chain), "-sample_fmt", "s32" if a.bits == 24 else f"s{a.bits}",
           "-c:a", "flac", "-compression_level", "8", str(master)]
    M.run(cmd)

    # verify: measure the resulting sections and report the boundary glide
    print("\nverification (after the ride):")
    prev = None
    for r in rows:
        seg = work / f"{r['section']:02d}.flac"
        out = work / f"{r['section']:02d}.post.flac"
        M.run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-ss", f"{r['start']:.3f}",
               "-i", str(master), "-t", f"{r['end'] - r['start']:.3f}",
               "-c:a", "flac", str(out)])
        got = M.measure(out, target, a.tp, a.lra)
        r["out_lufs"] = float(got["input_i"])
        r["out_tp"] = float(got["input_tp"])
        note = ""
        if prev is not None:
            ramp_s = ((r["end"] - r["start"]) + (rows[r["section"] - 2]["end"] - rows[r["section"] - 2]["start"])) / 2
            note = f"  glide {r['out_lufs'] - prev:+.2f} LU over ~{a.ramp:.0f}s"
        prev = r["out_lufs"]
        print(f"  {r['section']:02d} {r['title'][:30]:32s} -> {r['out_lufs']:7.2f} LUFS"
              f"  TP {r['out_tp']:5.2f}{note}")

    outs = [master]
    if a.mp3:
        mp3p = outdir / f"{src.stem}.smooth.mp3"
        M.run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(master),
               "-c:a", "libmp3lame", "-b:a", "320k", str(mp3p)])
        outs.append(mp3p)

    (outdir / "smooth-report.json").write_text(json.dumps(
        {"mode": "smoothed-continuous", "target_lufs": target, "ramp_s": a.ramp,
         "preset": a.preset, "comp": comp, "sections": rows,
         "outputs": [f.name for f in outs]}, indent=1))
    steps = [abs(rows[i]["out_lufs"] - rows[i - 1]["out_lufs"]) for i in range(1, len(rows))]
    print(f"\nmaster -> {master}")
    print(f"largest section-to-section change: {max(steps):.2f} LU, "
          f"delivered over ~{a.ramp:.0f}s of glide (no steps at joins)")
    print(f"report: {outdir / 'smooth-report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
