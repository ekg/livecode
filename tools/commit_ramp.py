#!/usr/bin/env python3
"""Ramp a lane through its git history.

Reads every committed version of a .tidal file, extracts one lane, pulls chosen
parameters out of each version, and emits a Tidal lane where those parameters are
an alternation of the distinct historical values.

  python3 tools/commit_ramp.py --file 189-breakbeat-machine.tidal --lane d6
  python3 tools/commit_ramp.py --file 189-breakbeat-machine.tidal --lane d7 \
      --params gain,amp,dry --as <...>            # alternation (default)
  python3 tools/commit_ramp.py --file 189-breakbeat-machine.tidal --lane d1 \
      --params gain --history                     # just show the table

Why this works: a lane's *structure* is Haskell, which cannot be data, but its
parameters are plain values. A commit is therefore a parameter vector plus a
structure, and the vectors can be sequenced with <...> while the structure stays
whatever the newest version is.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

NUM = r'(-?\d+(?:\.\d+)?)'
PARAM_RE = lambda p: re.compile(rf'#\s*{p}\s+(?:{NUM}|"([^"]*)")')


def commits_for(path: str) -> list[tuple[str, str]]:
    out = subprocess.run(
        ["git", "log", "--format=%h|%s", "--follow", "--", path],
        capture_output=True, text=True, check=True,
    ).stdout
    rows = []
    for line in out.splitlines():
        if "|" in line:
            h, subj = line.split("|", 1)
            rows.append((h.strip(), subj.strip()))
    return list(reversed(rows))  # oldest first


def lane_at(commit: str, path: str, lane: str) -> str | None:
    try:
        text = subprocess.run(
            ["git", "show", f"{commit}:{path}"],
            capture_output=True, text=True, check=True,
        ).stdout
    except subprocess.CalledProcessError:
        return None
    for line in text.splitlines():
        if line.startswith(lane + " $ "):
            return line
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--lane", required=True)
    ap.add_argument("--params", default="gain,amp,room,dry,crush")
    ap.add_argument("--history", action="store_true")
    ap.add_argument("--max", type=int, default=8, help="max distinct values per param")
    a = ap.parse_args()

    params = [p.strip() for p in a.params.split(",") if p.strip()]
    rows = []
    for h, subj in commits_for(a.file):
        line = lane_at(h, a.file, a.lane)
        if not line:
            continue
        vals = {}
        for p in params:
            m = PARAM_RE(p).search(line)
            if m:
                vals[p] = m.group(1) if m.group(1) is not None else m.group(2)
        rows.append((h, subj, vals, line))

    if not rows:
        print(f"no {a.lane} found in history of {a.file}", file=sys.stderr)
        return 1

    if a.history:
        print(f"{'commit':9} {'gain':22} {'amp':6} {'room':22} subject")
        for h, subj, vals, _ in rows:
            print(f"{h:9} {str(vals.get('gain','-'))[:21]:22} {str(vals.get('amp','-')):6} "
                  f"{str(vals.get('room','-'))[:21]:22} {subj[:60]}")
        return 0

    # distinct values per param, in historical order
    seqs = {}
    for p in params:
        seen = []
        for _, _, vals, _ in rows:
            v = vals.get(p)
            if v is not None and v not in seen:
                seen.append(v)
        if len(seen) > 1:
            seqs[p] = seen[-a.max:]
    if not seqs:
        print(f"{a.lane}: no parameter actually changed across history", file=sys.stderr)
        return 1

    base = rows[-1][3]
    out = base
    for p, seq in seqs.items():
        new = f'# {p} "<{" ".join(seq)}>"'
        out = PARAM_RE(p).sub(new, out, count=1) if PARAM_RE(p).search(out) else out + " " + new
    # stagger the cycles so params don't all switch together
    print(out)
    print("-- ramp: " + "; ".join(f"{p} over {len(s)} values" for p, s in seqs.items()), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
