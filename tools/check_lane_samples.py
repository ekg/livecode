#!/usr/bin/env python3
"""Resolve every lane's sample bank + index in a .tidal scene against what is ON DISK.

Why this exists: a scene can be *silent per lane* with no error anywhere. SuperDirt
drops an event whose bank is unknown, or whose `n` is past the end of the bank's file
list, and Tidal keeps reporting the stream as playing. Listening is the only way to
notice, which is too late and too slow. This makes it a table.

Usage:
    tools/check_lane_samples.py 177.tidal [--roots /home/erik/sounds,/home/erik/drummachines]

Reports per lane: bank, index used, files available, verdict. Verdicts:
    ok          index in range (or no index, bank has files)
    OUT-OF-RANGE  an index/`n` was asked for that the bank does not have -> silent
    MISSING-BANK  the bank directory was not found in any root            -> silent
    synth       no `s` in the lane (a SynthDef voice; not checkable here)

The bank search is by DIRECTORY NAME under the roots, matching how SuperDirt
resolves `s "name"` to a folder. Symlinks are followed.
"""
from __future__ import annotations

import os
import re
import sys
import glob

AUDIO_EXT = (".wav", ".aif", ".aiff", ".flac", ".ogg", ".wv")
DEFAULT_ROOTS = [
    os.path.expanduser("~/.local/share/SuperDirt/samples"),
    os.path.expanduser("~/sounds"),
    os.path.expanduser("~/sounds/mars_symlinks"),
    os.path.expanduser("~/drummachines"),
]
LANE_RE = re.compile(r"^d(\d+) \$ (.*)$")
S_RE = re.compile(r'\bs "([^"]+)"')
N_RE = re.compile(r'\bn "([^"]+)"')
CHOOSE_RE = re.compile(r"choose \[([^\]]*)\]")


def bank_dirs(roots):
    """map bank name -> list of candidate dirs"""
    found = {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        try:
            entries = os.listdir(root)
        except OSError:
            continue
        for name in entries:
            p = os.path.join(root, name)
            if os.path.isdir(p):
                found.setdefault(name, []).append(p)
    # also one level of subdirs under ~/samples/* (the packs are flat dirs of files,
    # but the loop packs are nested one deeper in places)
    for root in glob.glob(os.path.expanduser("~/samples/*")):
        if os.path.isdir(root):
            for name in os.listdir(root):
                p = os.path.join(root, name)
                if os.path.isdir(p):
                    found.setdefault(name, []).append(p)
    return found


def count_audio(dirs):
    best = 0
    for d in dirs:
        try:
            n = sum(1 for f in os.listdir(d) if f.lower().endswith(AUDIO_EXT))
        except OSError:
            n = 0
        best = max(best, n)
    return best


def tokens(sval):
    """split an `s` value into bank tokens, dropping mini-notation structure"""
    t = sval
    t = re.sub(r"\(\s*\d+\s*(,\s*\d+\s*)*\)", " ", t)   # euclid suffixes (p,k,r)
    t = re.sub(r"[\[\]{}*|,<>]", " ", t)
    return [x for x in t.split() if x]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    roots = DEFAULT_ROOTS
    for a in sys.argv[1:]:
        if a.startswith("--roots"):
            roots = a.split("=", 1)[1].split(",") if "=" in a else roots
    if not args:
        sys.exit(__doc__)
    path = args[0]
    banks = bank_dirs(roots)
    silent = []
    print(f"{'lane':5} {'bank':22} {'idx':10} {'files':>5}  verdict")
    for line in open(path):
        m = LANE_RE.match(line)
        if not m:
            continue
        lane, body = m.group(1), m.group(2)
        svals = S_RE.findall(body)
        if not svals:
            print(f"d{lane:4} {'-':22} {'-':10} {'-':>5}  synth")
            continue
        idxs = sorted({int(x) for x in re.findall(r"\d+", " ".join(N_RE.findall(body)))})
        for sval in svals:
            for tok in tokens(sval):
                if ":" in tok:
                    bank, _, idx = tok.partition(":")
                    try:
                        idx = int(float(idx))
                        asked = [idx]
                    except ValueError:
                        asked = idxs
                else:
                    bank, asked = tok, idxs
                dirs = banks.get(bank)
                if not dirs:
                    print(f"d{lane:4} {bank:22} {str(asked):10} {'?':>5}  MISSING-BANK  -> SILENT")
                    silent.append((lane, bank, "missing bank"))
                    continue
                n = count_audio(dirs)
                bad = [i for i in asked if i >= n]
                verdict = "ok" if not bad else f"OUT-OF-RANGE (has {n}) -> SILENT"
                if n == 0:
                    verdict = "EMPTY BANK -> SILENT"
                print(f"d{lane:4} {bank:22} {str(asked):10} {n:>5}  {verdict}")
                if bad or n == 0:
                    silent.append((lane, bank, verdict))
    print()
    if silent:
        print("SILENT / SUSPECT LANES:")
        for lane, bank, why in silent:
            print(f"  d{lane}: {bank} — {why}")
    else:
        print("all lanes resolve to existing banks and in-range indices")


if __name__ == "__main__":
    main()
