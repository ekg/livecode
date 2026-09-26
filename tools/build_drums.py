#!/usr/bin/env python3
"""Extract real-timing human drum voices from tunepile's Magenta Groove MIDI.
Usage: build_drums.py TAG:PATH [TAG:PATH ...]  -> /tmp/drums-<tag>.txt
Run with ~/tunepile/.venv/bin/python."""
import sys
from pathlib import Path
from collections import defaultdict
from music21 import midi
pile = Path('/home/erik/tunepile/midi/groove/groove')
VOICES = {
    'kick':  ([35, 36], 'p70kick', .62),
    'snare': ([37, 38, 40], 'p70snare', .55),
    'hat':   ([22, 26, 42, 44, 46], 'p70hat', .32),
    'clap':  ([39, 41, 43, 45, 47, 48, 50, 51, 53, 54, 57, 59], 'cp', .30),
}
for spec in sys.argv[1:]:
    tag, rel = spec.split(':', 1)
    mf = midi.MidiFile(); mf.open(str(pile / rel)); mf.read(); mf.close()
    length = 32 * mf.ticksPerQuarterNote
    buckets = {k: defaultdict(list) for k in VOICES}
    for track in mf.tracks:
        tick = 0
        for ev in track.events:
            if ev.isDeltaTime(): tick += ev.time
            elif ev.type == midi.ChannelVoiceMessages.NOTE_ON and ev.velocity > 0 and 0 <= tick < length:
                for name, (pitches, snd, ceil) in VOICES.items():
                    if ev.pitch in pitches:
                        soft = 'p70soft' if (name == 'snare' and ev.velocity <= 90) else snd
                        buckets[name][tick].append(f's "{soft}" # gain {ceil*(ev.velocity/127)**.5:.4f}')
                        break
    lines, counts = [], []
    for name in VOICES:
        notes = buckets[name]; times = sorted(notes); counts.append(len(times))
        parts = [(times[0], 'silence')] if times and times[0] else []
        for j, t in enumerate(times):
            dur = (times[j+1] if j+1 < len(times) else length) - t
            pat = notes[t][0] if len(notes[t]) == 1 else 'stack [' + ', '.join(notes[t]) + ']'
            parts.append((dur, '(' + pat + ')'))
        body = ', '.join(f'({d}, {p})' for d, p in parts)
        lines.append(f'let {tag}_{name} = slow 8 $ timeCat [{body}]')
    Path(f'/tmp/drums-{tag}.txt').write_text('\n\n'.join(lines) + '\n')
    print(f'{tag}: kick/snare/hat/clap = {counts}   ({rel})')
