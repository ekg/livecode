#!/usr/bin/env python3
"""Assemble a jam recording into a directory album.

Cuts a take into movements (curated or auto-merged from its markers file),
writes FLAC masters + MP3 320 sharing copies with ID3 tags, a track index,
and leaves room for cover.jpg in the album folder.

Usage:
  tools/make_album.py recordings/jam-20260923-1403.flac \
      --album "Nocturne Soul -> Machine Noise -> Lo-Fi" \
      --artist "erik + pi" --out albums/2026-09-23-nocturne-soul \
      --auto 10                # merge 39 marks down to ~10 movements
  tools/make_album.py jam.flac --cues cues.txt   # "mm:ss mm:ss Title" per line

Formats: FLAC masters (default) + MP3 320 (universal sharing). --extra opus
adds a smaller lossy copy for chat services that accept it.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

CODECS = {
    "flac": (["-c:a", "flac", "-compression_level", "8"], "flac"),
    "mp3": (["-c:a", "libmp3lame", "-b:a", "320k"], "mp3"),
    "opus": (["-c:a", "libopus", "-b:a", "160k"], "opus"),
}


def slug(s: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-zA-Z0-9]+", "-", s)).strip("-")


def duration(path: pathlib.Path) -> float:
    return float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True, check=True).stdout.strip())


def read_marks(path: pathlib.Path):
    out = []
    for line in path.open(encoding="utf-8", errors="replace"):
        try:
            o = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "rel" in o:
            out.append((float(o["rel"]), str(o.get("label", ""))))
    out.sort()
    return out


def auto_merge(marks, total: float, target: int):
    """Merge adjacent marks until roughly `target` movements remain."""
    marks = [(t, l) for t, l in marks if 0 <= t < total]
    while len(marks) > target:
        # merge the pair with the shortest span between them
        spans = [(marks[i + 1][0] - marks[i][0], i) for i in range(len(marks) - 1)]
        if not spans:
            break
        _, i = min(spans)
        marks.pop(i)
    return marks


def parse_cues(text: str, total: float):
    cues = []
    for line in text.splitlines():
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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("recording")
    ap.add_argument("--album", default="Untitled jam")
    ap.add_argument("--artist", default="erik + pi")
    ap.add_argument("--out", required=True, help="album directory to create")
    ap.add_argument("--auto", type=int, metavar="N",
                    help="auto-merge the marker file down to ~N movements")
    ap.add_argument("--cues", metavar="FILE", help="explicit cue list file")
    ap.add_argument("--extra", default="", help="extra formats, e.g. opus")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    rec = pathlib.Path(a.recording).expanduser().resolve()
    total = duration(rec)
    album = pathlib.Path(a.out).expanduser()
    album.mkdir(parents=True, exist_ok=True)

    if a.cues:
        tracks = parse_cues(pathlib.Path(a.cues).read_text(), total)
    else:
        marks = read_marks(rec.with_suffix(".markers.jsonl"))
        if not marks:
            tracks = [(0.0, total, rec.stem)]
        else:
            target = a.auto or len(marks) + 1
            marks = auto_merge(marks, total, target)
            # the first movement starts at the take's beginning
            marks[0] = (0.0, marks[0][1])
            tracks = []
            for i, (t, l) in enumerate(marks):
                end = marks[i + 1][0] if i + 1 < len(marks) else total
                tracks.append((t, end, l))

    fmts = ["flac", "mp3"] + ([f.strip() for f in a.extra.split(",") if f.strip()])
    index = []
    for n, (start, end, title) in enumerate(tracks, 1):
        length = end - start
        stem = f"{n:02d} - {slug(title) or 'movement'}"
        entry = {"track": n, "title": title, "start": round(start, 2),
                 "end": round(end, 2), "seconds": round(length, 1), "files": {}}
        print(f"{n:02d}  {int(start//60):d}:{start%60:04.1f}  {length:6.1f}s  {title}")
        for fmt in fmts:
            args, ext = CODECS[fmt]
            dst = album / f"{stem}.{ext}"
            if dst.exists() and not a.force:
                entry["files"][fmt] = dst.name
                continue
            subprocess.run(
                ["ffmpeg", "-y", "-v", "error", "-ss", f"{start:.3f}", "-i", str(rec),
                 "-t", f"{length:.3f}", *args,
                 "-metadata", f"title={title}",
                 "-metadata", f"album={a.album}",
                 "-metadata", f"artist={a.artist}",
                 "-metadata", f"album_artist={a.artist}",
                 "-metadata", f"track={n}/{len(tracks)}",
                 "-metadata", f"date=2026-09-23",
                 str(dst)], check=True)
            entry["files"][fmt] = dst.name
        index.append(entry)

    (album / "tracks.json").write_text(json.dumps(
        {"album": a.album, "artist": a.artist, "source": rec.name,
         "duration": round(total, 1), "tracks": index}, indent=1))

    lines = [f"# {a.album}", "", f"**{a.artist}** — live TidalCycles take, "
             f"{int(total//60)}m{int(total%60):02d}s, {len(tracks)} movements.", "",
             f"Source: `recordings/{rec.name}` (masters: FLAC, sharing: MP3 320).", "",
             "| # | start | len | title |", "|---|-------|-----|-------|"]
    for e in index:
        lines.append(f"| {e['track']:02d} | {int(e['start']//60)}:{int(e['start']%60):02d} "
                     f"| {e['seconds']:.0f}s | {e['title']} |")
    (album / "README.md").write_text("\n".join(lines) + "\n")
    print(f"\nalbum -> {album}  ({sum(1 for _ in album.iterdir())} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
