#!/usr/bin/env python3
"""Basic mastering pipeline: EBU R128 loudness normalisation + light glue + limiter.

Why it is built this way (a poor man's LANDR, but deterministic and inspectable):

1. **Measure first, then apply.** ffmpeg's `loudnorm` runs two passes. Pass 1
   measures integrated loudness (I, LUFS), true peak (TP), loudness range (LRA)
   and the gating threshold. Pass 2 applies the correction using those measured
   values in `linear=true` mode, which scales the whole track by one gain
   instead of dynamically riding it — that is the difference between "normalised"
   and "pumping mess".
2. **Normalise to a delivery standard, not to "as loud as possible".**
   -14 LUFS integrated is what Spotify/YouTube/Tidal normalise to anyway; going
   louder just gets turned back down (and squashed). -1.0 dBTP ceiling leaves
   headroom for lossy encoders, which overshoot by a few tenths of a dB.
3. **Compression is glue, not a weapon.** A 2:1 soft comp at ~-18 dB with a
   20 ms attack / 250 ms release tames peaks across a mix without flattening
   transients. Optional 2-band `mcompand` does it per frequency band.
4. **High-pass at 30 Hz** first: Tidal mixes carry sub-rumble that eats headroom
   and adds nothing audible; removing it buys loudness for free.
5. **Hard ceiling last.** `alimiter` at -1 dBTP guarantees nothing clips even if
   the compressor's makeup pushes the signal up.
6. **Verify after.** The output is measured again and compared to target, so a
   silent failure (wrong sample rate, mono downmix, bad measured values) shows up
   as a number, not as a surprise on someone else's speakers.

Usage:
  tools/master.py albums/<album>/*.flac                  # -14 LUFS, light glue
  tools/master.py track.flac --preset quiet              # -16 LUFS, no comp
  tools/master.py album/*.flac --preset loud --mp3       # club master + sharing
  tools/master.py album/*.flac --measure-only            # just report loudness
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

PRESETS = {
    # target LUFS, comp, softclip
    "share": (-14.0, "light", False),
    "quiet": (-16.0, "none", False),
    "loud": (-11.0, "medium", True),
    "reference": (-18.0, "none", False),
}

RE_JSON = re.compile(r"\{[^{}]*\"input_i\"[^{}]*\}", re.S)


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def measure(path: pathlib.Path, target: float, tp: float, lra: float,
            pre: list[str] | None = None) -> dict:
    """Pass 1: report loudness stats as JSON, measured AFTER the pre-chain.

    The pre-chain (high-pass + glue compression) must be included here, because
    loudnorm's linear mode trusts `measured_*` to compute its gain. Measuring the
    raw file and then inserting a compressor before loudnorm makes those numbers
    describe a signal that no longer exists at loudnorm's input — which is how
    this pipeline first produced tracks 4 LU off target.
    """
    chain = list(pre or []) + [
        f"loudnorm=I={target}:TP={tp}:LRA={lra}:print_format=json"]
    p = run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", ",".join(chain),
             "-f", "null", "-"])
    m = RE_JSON.search(p.stderr)
    if not m:
        raise RuntimeError(f"loudnorm produced no report for {path.name}:\n{p.stderr[-800:]}")
    return json.loads(m.group(0))


def comp_filter(kind: str) -> list[str]:
    """Glue compression.

    light  = one 2:1 stage, slow-ish, just taming peaks across the mix.
    medium = two chained stages (fast peak tamer + slow glue). Lowering peaks
             is also what buys headroom on limiter-bound material, so this is
             the lever for tracks that sit below target because of the ceiling.
    """
    if kind == "none":
        return []
    if kind == "light":
        return ["acompressor=threshold=-18dB:ratio=2:attack=20:release=250:makeup=1"]
    if kind == "medium":
        return ["acompressor=threshold=-16dB:ratio=2.5:attack=8:release=120:makeup=1",
                "acompressor=threshold=-24dB:ratio=2:attack=40:release=500:makeup=1"]
    if kind == "heavy":
        return ["acompressor=threshold=-18dB:ratio=3:attack=5:release=90:makeup=1",
                "acompressor=threshold=-26dB:ratio=2.5:attack=40:release=500:makeup=1",
                "acompressor=threshold=-12dB:ratio=1.5:attack=80:release=800:makeup=1"]
    raise ValueError(kind)


def master_one(src: pathlib.Path, outdir: pathlib.Path, preset: str,
               tp: float, lra: float, hpf: float, mp3: bool,
               bits: int | None, report: list, iterations: int = 2,
               fixed_gain: float | None = None) -> None:
    target, comp, softclip = PRESETS[preset]

    # the chain loudnorm actually sees, used for BOTH measurement and application
    pre: list[str] = []
    if hpf > 0:
        pre.append(f"highpass=f={hpf}")
    pre += comp_filter(comp)

    stats = measure(src, target, tp, lra, pre)
    measured_lufs = float(stats["input_i"])

    if fixed_gain is not None:
        # album mode: one gain for every track (from the loudest one) so the
        # record keeps its internal dynamics instead of every movement being
        # dragged to the same integrated loudness.
        gain = fixed_gain
        chain = list(pre) + [f"volume={gain:+.2f}dB"]
        if softclip:
            chain.append("asoftclip=type=tanh:threshold=-3dB")
        chain.append(f"alimiter=limit={10 ** ((tp - 0.3) / 20.0):.4f}:level=disabled")
        outdir.mkdir(parents=True, exist_ok=True)
        flac = outdir / f"{src.stem}.flac"
        cmd = ["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(src),
               "-af", ",".join(chain)]
        if bits:
            cmd += ["-sample_fmt", f"s{bits}"]
        cmd += ["-c:a", "flac", "-compression_level", "8", str(flac)]
        run(cmd)
        got = measure(flac, target, tp, lra)
        outs = [flac]
        if mp3:
            mp3p = outdir / f"{src.stem}.mp3"
            run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(flac),
                 "-c:a", "libmp3lame", "-b:a", "320k", str(mp3p)])
            outs.append(mp3p)
        report.append({
            "file": src.name, "in_lufs": measured_lufs, "in_tp": float(stats["input_tp"]),
            "in_lra": float(stats["input_lra"]), "out_lufs": float(got["input_i"]),
            "out_tp": float(got["input_tp"]), "out_lra": float(got["input_lra"]),
            "target": target, "mode": "album-gain", "gain_applied_lu": round(gain, 2),
            "trim_lu": round(gain, 2), "error_lu": round(float(got["input_i"]) - target, 2),
            "outputs": [f.name for f in outs],
        })
        print(f"{src.name:44s} {measured_lufs:7.2f} -> {float(got['input_i']):6.2f} LUFS"
              f"  TP {float(got['input_tp']):5.2f}dB  LRA {float(got['input_lra']):5.2f}"
              f"  album-gain {gain:+5.2f}")
        return

    # iterate: limiting on hot material can leave the output short of target, so
    # measure the result and add the residual gain (before the limiter) again.
    trim = 0.0
    got = None
    flac = outdir / f"{src.stem}.flac"
    for attempt in range(iterations + 1):
        chain = list(pre)
        chain.append(
            f"loudnorm=I={target}:TP={tp}:LRA={lra}:linear=true"
            f":measured_I={stats['input_i']}:measured_TP={stats['input_tp']}"
            f":measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}"
            f":offset={stats['target_offset']}")
        if trim:
            chain.append(f"volume={trim:+.2f}dB")
        if softclip:
            chain.append("asoftclip=type=tanh:threshold=-3dB")
        chain.append(f"alimiter=limit={10 ** ((tp - 0.3) / 20.0):.4f}:level=disabled")

        cmd = ["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(src),
               "-af", ",".join(chain)]
        if bits:
            cmd += ["-sample_fmt", f"s{bits}"]
        cmd += ["-c:a", "flac", "-compression_level", "8", str(flac)]
        run(cmd)

        got = measure(flac, target, tp, lra)
        err = target - float(got["input_i"])
        # only chase the residual while there is headroom left to spend
        if abs(err) <= 0.3 or (err > 0 and float(got["input_tp"]) >= tp - 0.15):
            break
        trim += err

    outs = [flac]
    if mp3:
        mp3p = outdir / f"{src.stem}.mp3"
        run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", str(flac),
             "-c:a", "libmp3lame", "-b:a", "320k", str(mp3p)])
        outs.append(mp3p)

    row = {
        "file": src.name,
        "in_lufs": float(stats["input_i"]), "in_tp": float(stats["input_tp"]),
        "in_lra": float(stats["input_lra"]),
        "out_lufs": float(got["input_i"]), "out_tp": float(got["input_tp"]),
        "out_lra": float(got["input_lra"]),
        "target": target,
        "gain_applied_lu": round(target - float(stats["input_i"]) + trim, 2),
        "trim_lu": round(trim, 2),
        "error_lu": round(float(got["input_i"]) - target, 2),
        "outputs": [f.name for f in outs],
    }
    report.append(row)
    warn = "" if abs(row["error_lu"]) <= 0.5 else "  <-- off target (limiter-bound)"
    print(f"{src.name:44s} {row['in_lufs']:7.2f} -> {row['out_lufs']:6.2f} LUFS"
          f"  TP {row['out_tp']:5.2f}dB  LRA {row['out_lra']:5.2f}"
          f"  trim {trim:+5.2f}{warn}")


def measure_only(files: list[pathlib.Path], target: float, tp: float, lra: float,
                 hpf: float = 0.0, comp: str = "none"):
    pre: list[str] = []
    if hpf > 0:
        pre.append(f"highpass=f={hpf}")
    pre += comp_filter(comp)
    rows = []
    for f in files:
        s = measure(f, target, tp, lra, pre or None)
        rows.append({"file": f.name, "lufs": float(s["input_i"]),
                     "tp": float(s["input_tp"]), "lra": float(s["input_lra"])})
        print(f"{f.name:44s} {rows[-1]['lufs']:7.2f} LUFS  "
              f"TP {rows[-1]['tp']:5.2f}dB  LRA {rows[-1]['lra']:5.2f}")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--preset", choices=sorted(PRESETS), default="share")
    ap.add_argument("--out", default=None, help="output dir (default: <first dir>/mastered)")
    ap.add_argument("--tp", type=float, default=-1.0, help="true peak ceiling dBTP")
    ap.add_argument("--lra", type=float, default=11.0, help="target loudness range")
    ap.add_argument("--hpf", type=float, default=30.0, help="high-pass Hz (0 = off)")
    ap.add_argument("--comp", choices=["none", "light", "medium", "heavy"],
                    default=None, help="override the preset's compression")
    ap.add_argument("--mp3", action="store_true", help="also write MP3 320")
    ap.add_argument("--bits", type=int, choices=[16, 24], default=None,
                    help="force output bit depth")
    ap.add_argument("--measure-only", action="store_true")
    ap.add_argument("--album-gain", action="store_true",
                    help="apply ONE gain to every track (from the loudest, set to "
                         "target) so the record keeps its internal dynamics")
    a = ap.parse_args()

    files = [pathlib.Path(f).expanduser().resolve() for f in a.files]
    missing = [f for f in files if not f.exists()]
    if missing:
        print("missing: " + ", ".join(str(m) for m in missing), file=sys.stderr)
        return 1

    if a.measure_only:
        rows = measure_only(files, PRESETS[a.preset][0], a.tp, a.lra)
        out = files[0].parent / "loudness.json"
        out.write_text(json.dumps(rows, indent=1))
        print(f"-> {out}")
        return 0

    if a.comp:
        PRESETS[a.preset] = (PRESETS[a.preset][0], a.comp, PRESETS[a.preset][2])

    outdir = pathlib.Path(a.out).expanduser() if a.out else files[0].parent / "mastered"
    report: list = []
    fixed = None
    if a.album_gain:
        pre: list[str] = []
        if a.hpf > 0:
            pre.append(f"highpass=f={a.hpf}")
        pre += comp_filter(PRESETS[a.preset][1])
        loudest = -999.0
        for f in files:
            l = float(measure(f, PRESETS[a.preset][0], a.tp, a.lra, pre or None)["input_i"])
            loudest = max(loudest, l)
        fixed = PRESETS[a.preset][0] - loudest
        print(f"album mode: loudest track {loudest:.2f} LUFS -> one gain of "
              f"{fixed:+.2f} dB for all tracks\n")
    for f in files:
        master_one(f, outdir, a.preset, a.tp, a.lra, a.hpf, a.mp3, a.bits, report,
                   fixed_gain=fixed)

    (outdir / "master-report.json").write_text(json.dumps(
        {"preset": a.preset, "target_lufs": PRESETS[a.preset][0], "tp": a.tp,
         "lra": a.lra, "hpf": a.hpf, "comp": PRESETS[a.preset][1],
         "tracks": report}, indent=1))
    print(f"\n{len(report)} track(s) -> {outdir}")
    if a.album_gain:
        lo = min(r["out_lufs"] for r in report)
        hi = max(r["out_lufs"] for r in report)
        print(f"album mode: tracks span {hi:.2f} .. {lo:.2f} LUFS "
              f"(loudest at target, dynamics preserved)")
    else:
        errs = [r["error_lu"] for r in report]
        off = [r["file"] for r in report if abs(r["error_lu"]) > 0.5]
        print(f"worst target error: {max(abs(e) for e in errs):.2f} LU"
              + (f"  ({len(off)} limiter-bound)" if off else ""))
    print(f"report: {outdir / 'master-report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
