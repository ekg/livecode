#!/usr/bin/env python3
"""calibrate_levels.py — systematic source loudness for the livecode sample library.

SuperDirt does not normalize sample loudness, so every alias arrives at a
different level and mixes have to be hand-balanced (the seesaw). This tool
measures the RMS of every sample file behind our aliases and writes
sc/levels.tsv with a suggested base gain per alias (to reach ~0.2 RMS at
unity playback). Scene gains then MULTIPLY that base instead of guessing.

Usage: python3 tools/calibrate_levels.py [--target 0.2]
Reads sc/samples*.scd (loadSoundFile calls), writes sc/levels.tsv.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = 0.2
CAP = 3.0

CALL = re.compile(
    r'(?:\[(\\?[\w]+)\s*,\s*"([^"]+)"\]\s*,?'                     # [\alias, "path"]
    r'|loadSoundFile\(\s*"([^"]+)"\s*,\s*\\?([\w]+)\s*\))'         # loadSoundFile("path", \alias)
)


def rms_linear(path: Path) -> float | None:
    try:
        out = subprocess.run(
            ["ffmpeg", "-i", str(path), "-map", "0:a:0",
             "-af", "astats=measure_overall=RMS_level:measure_perchannel=none",
             "-f", "null", "-"],
            capture_output=True, text=True, timeout=30)
        m = re.search(r"RMS level dB:\s*(-?[\d.]+|-inf)", out.stderr)
        if not m:
            return None
        if m.group(1) == "-inf":
            return 0.0
        db = float(m.group(1))
        return 10 ** (db / 20) if db > -90 else 0.0
    except Exception:
        return None


def main() -> None:
    if "--target" in sys.argv:
        TARGET = float(sys.argv[sys.argv.index("--target") + 1])
    rows = []
    for scd in sorted(ROOT.glob("sc/samples*.scd")):
        text = scd.read_text()
        for m in CALL.finditer(text):
            alias, path = (m.group(1), m.group(2)) if m.group(2) else (m.group(4), m.group(3))
            alias = alias.lstrip("\\")
            p = Path(path)
            if not p.is_absolute():
                p = ROOT / p
            if not p.exists():
                rows.append((alias, path, None, None))
                continue
            rms = rms_linear(p)
            if rms is None:
                rows.append((alias, path, None, None))
                continue
            gain = min(CAP, TARGET / rms) if rms > 0 else CAP
            rows.append((alias, path, rms, gain))
    out = ROOT / "sc/levels.tsv"
    with out.open("w") as f:
        f.write("# alias\tpath\trms\tsuggested_gain (toward RMS %.2f)\n" % TARGET)
        for alias, path, rms, gain in rows:
            f.write("%s\t%s\t%s\t%s\n" % (
                alias, path,
                "MISSING" if rms is None and path else ("%.4f" % rms if rms is not None else "-"),
                "%.3f" % gain if gain is not None else "-"))
    measured = sum(1 for r in rows if r[2] is not None)
    missing = [r for r in rows if r[0] and r[2] is None]
    print(f"calibrated {measured}/{len(rows)} aliases -> sc/levels.tsv")
    if missing:
        print("missing/unreadable:", ", ".join(r[0] for r in missing))


if __name__ == "__main__":
    main()
