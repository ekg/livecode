#!/usr/bin/env python3
"""Split a jam recording into shareable segments using its markers file.

The pi-tidal recording tool writes <jam>.markers.jsonl, where each line is
{"t": iso8601, "rel": seconds_into_take, "label": ..., "git": ...}. Every
tidal_mark becomes a cut point, so a performance can be exported as tracks.

Short markers (an experiment three seconds after the previous one) are merged
into the following segment by default — the point of a segment is to be
listenable, not to mirror every edit.

Usage:
  tools/split_jam.py recordings/jam-20260923-1403.flac
  tools/split_jam.py jam.flac --min-length 60 --formats flac,mp3,opus
  tools/split_jam.py jam.flac --all-marks        # no merging, one file per mark

Formats: flac (lossless), mp3, opus, m4a, wav.
MP3 is for compatibility, Opus for size/quality, m4a for Apple devices.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys

CODECS = {
    "flac": (["-c:a", "flac", "-compression_level", "8"], "flac"),
    "wav": (["-c:a", "pcm_s16le"], "wav"),
    "mp3": (["-c:a", "libmp3lame", "-b:a", "320k"], "mp3"),
    "opus": (["-c:a", "libopus", "-b:a", "160k", "-vbr", "on"], "opus"),
    "m4a": (["-c:a", "aac", "-b:a", "192k"], "m4a"),
}


def slug(s: str, maxlen: int = 42) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:maxlen].strip("-") or "segment"


def read_marks(path: pathlib.Path):
    marks = []
    for line in path.open(encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "rel" in o:
            marks.append((float(o["rel"]), str(o.get("label", ""))))
    marks.sort()
    return marks


def build_segments(marks, duration: float, min_length: float, merge: bool):
    if not marks:
        return [(0.0, duration, "full")]
    segs = []
    for i, (t, label) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else duration
        segs.append([t, end, label])
    # drop zero/negative length and unnamed boundary duplicates
    segs = [s for s in segs if s[1] - s[0] > 0.05]
    if merge:
        out = []
        for s in segs:
            if out and (s[1] - out[-1][0]) < min_length and len(out) > 1:
                # absorb this mark into the previous segment: keep the earlier
                # start, adopt the later end and label? no — extend previous end
                out[-1][1] = s[1]
            elif out and (s[1] - s[0]) < min_length and len(out) == 1:
                out[-1][1] = s[1]
            else:
                out.append(s)
        segs = out
    return [(a, b, l) for a, b, l in segs]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("recording", help="jam .flac/.wav (its .markers.jsonl is used)")
    ap.add_argument("--formats", default="flac,mp3,opus",
                    help="comma list of flac,mp3,opus,m4a,wav (default flac,mp3,opus)")
    ap.add_argument("--min-length", type=float, default=45.0,
                    help="merge segments shorter than this many seconds (default 45)")
    ap.add_argument("--all-marks", action="store_true", help="no merging")
    ap.add_argument("--out", default=None, help="output dir (default: <recording dir>/segments)")
    ap.add_argument("--force", action="store_true", help="overwrite existing files")
    a = ap.parse_args()

    rec = pathlib.Path(a.recording).expanduser().resolve()
    if not rec.exists():
        print(f"missing {rec}", file=sys.stderr)
        return 1
    marks_path = rec.with_suffix(".markers.jsonl")
    marks = read_marks(marks_path) if marks_path.exists() else []
    duration = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(rec)],
        capture_output=True, text=True, check=True).stdout.strip())

    segs = build_segments(marks, duration, a.min_length, merge=not a.all_marks)
    outdir = pathlib.Path(a.out).expanduser() if a.out else rec.parent / "segments"
    outdir.mkdir(parents=True, exist_ok=True)

    fmts = [f.strip() for f in a.formats.split(",") if f.strip()]
    base = rec.stem
    index = []
    for n, (start, end, label) in enumerate(segs, 1):
        length = end - start
        stem = f"{base}__{n:02d}-{slug(label)}"
        tt = f"{int(start//60):02d}{start%60:05.2f}"
        print(f"[{n:02d}] {tt}  {length:6.1f}s  {label}")
        for fmt in fmts:
            args, ext = CODECS[fmt]
            dst = outdir / f"{stem}.{ext}"
            if dst.exists() and not a.force:
                print(f"      exists {dst.name}")
                continue
            subprocess.run(
                ["ffmpeg", "-y", "-v", "error", "-ss", f"{start:.3f}",
                 "-i", str(rec), "-t", f"{length:.3f}", *args, str(dst)],
                check=True)
            index.append({"segment": n, "start": round(start, 2),
                          "end": round(end, 2), "label": label,
                          "format": fmt, "file": dst.name,
                          "size": dst.stat().st_size})
    idxp = outdir / f"{base}__segments.json"
    idxp.write_text(json.dumps(index, indent=1))
    print(f"\n{len(segs)} segments x {len(fmts)} formats -> {outdir}")
    print(f"index: {idxp}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
