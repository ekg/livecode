#!/usr/bin/env python3
"""Rename a take's files to a real name, keeping the timestamp.

The pi-tidal recorder writes `<prefix>-YYYYMMDD-HHMM.wav` (+ `.flac`, `.mp3`,
`.markers.jsonl`). It can be named at record time (`tidal_record name=...`, which
slugifies), but for takes already on disk this renames the whole set at once —
including any album directory that was built from it.

Usage:
  tools/rename_take.py recordings/jam-20261004-1137.flac "Jolene in the Riddim"
  tools/rename_take.py <any-file-of-the-take> <new name> [--album albums/<dir>]

The timestamp (YYYYMMDD-HHMM) is preserved, so the slug is a readable prefix and
takes still sort chronologically:
  jam-20261004-1137.*  ->  jolene-in-the-riddim-20261004-1137.*
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

EXTS = (".wav", ".flac", ".mp3", ".markers.jsonl")


def slug(name: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-zA-Z0-9]+", "-", name)).strip("-").lower()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", help="any file of the take (e.g. recordings/jam-...flac)")
    ap.add_argument("name", help="new title, e.g. 'Jolene in the Riddim'")
    ap.add_argument("--album", help="album directory built from this take (renamed too)")
    a = ap.parse_args()

    p = pathlib.Path(a.file)
    # split off extension(s): <stem>-YYYYMMDD-HHMM.<ext>
    m = re.match(r"^(.*?)-(\d{8}-\d{4})(\..*)?$", p.name)
    if not m:
        sys.exit(f"cannot find a YYYYMMDD-HHMM timestamp in {p.name!r}")
    old_prefix, stamp, ext = m.group(1), m.group(2), m.group(3) or ".wav"
    s = slug(a.name)
    if not s:
        sys.exit("name slugified to nothing — give it letters/digits")

    moves = 0
    for e in EXTS:
        src = p.with_name(f"{old_prefix}-{stamp}{e}")
        if src.exists():
            dst = src.with_name(f"{s}-{stamp}{e}")
            src.rename(dst)
            print(f"{src.name}  ->  {dst.name}")
            moves += 1
    # rewrite references inside an album that used the old file name
    if a.album:
        album = pathlib.Path(a.album)
        for f in album.rglob("*"):
            if f.is_file() and f.suffix in (".md", ".json", ".txt"):
                try:
                    t = f.read_text()
                except (UnicodeDecodeError, OSError):
                    continue
                n = t.replace(f"{old_prefix}-{stamp}", f"{s}-{stamp}")
                if n != t:
                    f.write_text(n)
                    print(f"updated refs in {f}")
    if not moves:
        sys.exit(f"no files named {old_prefix}-{stamp}.* next to {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
