#!/usr/bin/env python3
"""Flag multi-line Tidal constructs in .tidal files.

Why this exists: a chunk is re-sent to the REPL as a unit, but only if it stays
one unit. A pattern written as

    d4 $ fast 2 $ cat [
      s "superpiano" # note "...",
      s "superpiano" # note "..."
    ] # gain 0.5

is valid when evaluated whole — and a parse error ("possibly incorrect
indentation or mismatched brackets") the moment anything sends a fragment of it,
or splits it on a blank line. Since the whole workflow is "the agent sends
patterns to a REPL", the safe convention is **one stream per line**.

Usage:
  tools/check_tidal.py            # check every .tidal file
  tools/check_tidal.py 53.tidal   # check specific files
Exit code 1 if any file has multi-line constructs.
"""
from __future__ import annotations

import glob
import pathlib
import sys


def scan(path: pathlib.Path):
    """Return [(lineno, text, reason)] for lines that open a construct.

    Skips the body of multi-line strings and lines inside `{- -}` comments;
    flags a line whose brackets/quotes do not close on that line.
    """
    issues = []
    lines = path.read_text(errors="replace").splitlines()
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith("--"):
            continue
        depth_q = 0
        brackets = 0
        j = 0
        while j < len(s):
            c = s[j]
            if c == "\\" and depth_q:
                j += 2
                continue
            if c == '"':
                depth_q ^= 1
            elif not depth_q and c in "([{":
                brackets += 1
            elif not depth_q and c in ")]}":
                brackets -= 1
            j += 1
        if depth_q or brackets > 0:
            nxt = lines[i].strip() if i < len(lines) else ""
            if nxt and not nxt.startswith("--"):
                reason = "unclosed quote" if depth_q else "unclosed bracket"
                issues.append((i, s[:70], reason))
    return issues


def fix(path: pathlib.Path):
    """Join multi-line constructs into single lines, in place.

    Only touches lines whose brackets/quotes do not close on that line: the
    continuation lines are folded in until balance is restored. Comment-only and
    blank lines are preserved as separators, so a `do` block (which has no
    unclosed bracket of its own) is left alone.
    """
    lines = path.read_text(errors="replace").splitlines()
    out, i, changed = [], 0, 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if not s or s.startswith("--"):
            out.append(line)
            i += 1
            continue
        q = 0
        bal = 0
        j = 0
        while j < len(s):
            c = s[j]
            if c == "\\" and q:
                j += 2
                continue
            if c == '"':
                q ^= 1
            elif not q and c in "([{":
                bal += 1
            elif not q and c in ")]}":
                bal -= 1
            j += 1
        if q or bal > 0:
            parts = [s]
            i += 1
            while i < len(lines) and (q or bal > 0):
                nxt = lines[i].strip()
                if nxt.startswith("--"):
                    break
                parts.append(nxt)
                j = 0
                while j < len(nxt):
                    c = nxt[j]
                    if c == "\\" and q:
                        j += 2
                        continue
                    if c == '"':
                        q ^= 1
                    elif not q and c in "([{":
                        bal += 1
                    elif not q and c in ")]}":
                        bal -= 1
                    j += 1
                i += 1
            out.append(" ".join(parts))
            changed += 1
        else:
            out.append(line)
            i += 1
    if changed:
        path.write_text("\n".join(out) + "\n")
    return changed


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--fix"]
    do_fix = "--fix" in sys.argv
    files = [pathlib.Path(a) for a in args] if args else \
        [pathlib.Path(p) for p in sorted(glob.glob("*.tidal"))]
    if do_fix:
        total = 0
        for f in files:
            n = fix(f)
            if n:
                total += n
                print(f"{f}: joined {n} multi-line construct(s)")
        print(f"\nfixed {total} construct(s) across {len(files)} file(s)")
    bad = 0
    for f in files:
        issues = scan(f)
        if issues:
            bad += 1
            print(f"{f}: {len(issues)} multi-line construct(s)")
            for ln, text, reason in issues[:4]:
                print(f"   line {ln} ({reason}): {text}")
    if bad:
        print(f"\n{bad} file(s) contain multi-line constructs — rewrite each affected "
              f"stream onto ONE line (see the note in sc/README.md)")
        return 1
    print(f"checked {len(files)} file(s): all patterns are single-line")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
