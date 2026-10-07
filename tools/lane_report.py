#!/usr/bin/env python3
"""Per-lane text report for a .tidal scene: reads the d* lines and prints, per lane,
the event density, mean gain, mean filter band (lpf/hpf) and the sources it plays.

This is CODE-level analysis, not audio: it answers "how present is each lane, and in
what band does it sit?" from the pattern itself. It does NOT measure the actual mix
(for that, in scene mode use ~deckScanStart/~orbitScanReport; per-orbit audio needs
legacy routing, since scene mode bypasses each orbit's dryBus).

Usage: python3 tools/lane_report.py 171.tidal
"""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
CYCLES = 64

commands = [
    ":set -XOverloadedStrings -Wno-type-defaults",
    "import Sound.Tidal.Boot",
    "default (Rational, Integer, Double, Pattern String)",
    "import qualified Data.Map.Strict as M",
    "import Data.List (intercalate, nub)",
]
# project params (ddSend, verbSend, drive, ...) are declared as `let` in BootTidal.hs
commands += [line for line in (root / "BootTidal.hs").read_text().splitlines()
             if line.startswith("let ")]
# every `let` binding defines gates/swing/pad/etc. that the lanes reference
text = pathlib.Path(sys.argv[1]).read_text() if len(sys.argv) > 1 else ""
if not text:
    sys.exit(__doc__)
for line in text.splitlines():
    if line.startswith("let "):
        commands.append(line)

lanes = []  # (name, rhs)
for line in text.splitlines():
    m = re.fullmatch(r"(d\d+)\s*\$\s*(.*)", line)
    if m:
        lanes.append((m.group(1), m.group(2)))
if not lanes:
    sys.exit(f"{sys.argv[1]}: no d-lanes found")

commands += [
    'let getFp k e = case M.lookup k (value e) of { Just v -> getF v; Nothing -> Nothing }',
    f'let evs p = queryArc p (Arc 0 {CYCLES})',
    f'let eper p = fromIntegral (length (evs p)) / {CYCLES} :: Double',
    'let mn xs = if null xs then 0 else sum xs / fromIntegral (length xs)',
    'let vals k p = [d | e <- evs p, Just d <- [getFp k e]]',
    'let srcs p = nub [s | e <- evs p, Just s <- [M.lookup "s" (value e) >>= getS]]',
    'let rep name p = putStrLn (intercalate "\\t" [name, show (eper p), show (mn (vals "gain" p)), show (mn (vals "cutoff" p)), show (mn (vals "hcutoff" p)), show (mn (vals "pan" p)), intercalate "," (srcs p)])',
]
for name, rhs in lanes:
    commands.append(f"let lane_{name} = {rhs}")
for name, _ in lanes:
    commands.append(f'rep "{name}" lane_{name}')
commands.append(":quit")

result = subprocess.run(["ghci", "-ignore-dot-ghci", "-v0"], input="\n".join(commands) + "\n",
                        text=True, capture_output=True, cwd=root, timeout=120)
rows = []
for line in result.stdout.splitlines():
    parts = line.rstrip("\n").split("\t")
    if len(parts) == 7 and re.fullmatch(r"d\d+", parts[0]):
        rows.append(parts)

if not rows:
    print(result.stdout, end="")
    print(result.stderr, file=sys.stderr, end="")
    sys.exit("lane_report: no rows parsed (ghci error above?)")

def fnum(s):
    try:
        return float(s)
    except ValueError:
        return 0.0

rows.sort(key=lambda r: -(fnum(r[1]) * fnum(r[2])))  # density x gain
print(f"{'lane':>4} {'ev/cyc':>7} {'gain':>6} {'lpf':>7} {'hpf':>7} {'pan':>5}  sources")
print("-" * 74)
for r in rows:
    print(f"{r[0]:>4} {fnum(r[1]):7.2f} {fnum(r[2]):6.2f} {fnum(r[3]):7.0f} "
          f"{fnum(r[4]):7.0f} {fnum(r[5]):5.2f}  {r[6]}")
print("-" * 74)
print(f"{len(rows)} lanes; presence proxy = ev/cyc x gain (code-level, not audio).")
