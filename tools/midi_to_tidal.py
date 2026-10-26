#!/usr/bin/env python3
"""Convert a MIDI capture log into a Tidal note pattern.

  python3 tools/midi_to_tidal.py ~/midi-capture.jsonl                  # 1 bar per <...>
  python3 tools/midi_to_tidal.py ~/midi-capture.jsonl --bars 4         # 4 bars per element
  python3 tools/midi_to_tidal.py ~/midi-capture.jsonl --scale e:minor  # snap to E minor
  python3 tools/midi_to_tidal.py ~/midi-capture.jsonl --name d12       # emit a full lane

Quantises to a 16th-of-a-cycle grid, writes rests as `~`, stacks simultaneous
notes into [..] chords, and can snap to a named scale so the line can't leave the
key the piece is in.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

NOTES = ["c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"]
SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
}


def name_of(midi: int) -> str:
    return f"{NOTES[midi % 12]}{(midi // 12) - 1}"


def snap(midi: int, root_pc: int, scale: list[int]) -> int:
    best, best_d = midi, 99
    for octave in range(-2, 3):
        for interval in scale:
            cand = midi + ((root_pc + interval + 12 * octave) - midi % 12 + 6) % 12 - 6
            d = abs(cand - midi)
            if d < best_d:
                best, best_d = cand, d
    return best


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--bars", type=int, default=1, help="cycles per <...> element")
    ap.add_argument("--steps", type=int, default=16, help="grid per cycle")
    ap.add_argument("--scale", default=None, help="root:scale, e.g. e:minor")
    ap.add_argument("--name", default=None, help="emit a full d-channel lane")
    ap.add_argument("--sound", default="hoRhodes")
    ap.add_argument("--json", action="store_true", help="emit the raw grid as JSON")
    ap.add_argument("--cps", type=float, default=None,
                    help="override tempo in cycles/sec (the log records sclang's clock, not Tidal's)")
    ap.add_argument("--trim", type=float, default=0.0,
                    help="drop notes before this many seconds into the log")
    a = ap.parse_args()

    lines = [json.loads(l) for l in pathlib.Path(a.log).read_text().splitlines() if l.strip()]
    if not lines:
        print("empty log", file=sys.stderr)
        return 1
    t0 = lines[0].get("t0", 0.0)
    cps = a.cps if a.cps is not None else lines[0].get("cps", 0.45)
    t_start = t0 + (a.trim or 0.0)

    root_pc = None
    scale = None
    if a.scale:
        root, _, sname = a.scale.partition(":")
        root_pc = NOTES.index(root) if root in NOTES else 0
        scale = SCALES.get(sname or "minor", SCALES["minor"])

    # pair note-on / note-off
    sounding: dict[int, tuple[float, int]] = {}
    notes: list[tuple[float, float, int, int]] = []
    for ev in lines[1:]:
        t = (ev["t"] - t_start) * cps  # -> cycles since start
        n = ev["n"]
        if ev.get("on"):
            sounding[n] = (t, ev.get("v", 100))
        elif n in sounding:
            st, vel = sounding.pop(n)
            notes.append((st, t - st, n, vel))
    for n, (st, vel) in sounding.items():  # unterminated notes -> short
        notes.append((st, 0.25, n, vel))

    if not notes:
        print("no notes captured", file=sys.stderr)
        return 1

    notes = [n for n in notes if n[0] >= -0.01]
    if not notes:
        print("no notes after trim", file=sys.stderr)
        return 1
    end = max(st + dur for st, dur, _, _ in notes)
    ncycles = max(1, int(end + 0.999))
    grid: dict[int, set[int]] = {}
    for st, dur, n, vel in notes:
        slot = int(round(st * a.steps))
        pitch = snap(n, root_pc, scale) if (scale is not None and root_pc is not None) else n
        grid.setdefault(slot, set()).add(pitch)

    if a.json:
        print(json.dumps({str(k): sorted(v) for k, v in grid.items()}, indent=1))
        return 0

    total = ncycles * a.steps
    tokens = []
    for i in range(total):
        p = sorted(grid.get(i, ()))
        if not p:
            tokens.append("~")
        elif len(p) == 1:
            tokens.append(name_of(p[0]))
        else:
            tokens.append("[" + ",".join(name_of(x) for x in p) + "]")

    per = a.bars * a.steps
    bars = [" ".join(tokens[i:i + per]) for i in range(0, len(tokens), per)]
    body = " ".join(f"[{b}]" for b in bars)

    if a.name:
        print(f'{a.name} $ slow {a.bars} $ note "<{body}>" # s "{a.sound}" # orbit 3 # gain 0.5 # amp 0.5 # hpf 350 # lpf 5000 # attack 0.02 # release 0.5 # sustain 0.4 # room 0.6 # size 0.9 # dry 0.65')
    else:
        print(f'slow {a.bars} $ note "<{body}>"')
    print(f"-- {len(notes)} notes over {ncycles} cycles at cps {cps:.4f} "
          f"({a.steps}/cycle grid, {a.bars} cycle(s) per element)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
