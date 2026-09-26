#!/usr/bin/env python3
"""Scene 87 support: two fresh Groove MIDI performances + Air 'Cherry Blossom Girl'
arpeggio transposed into D. Run with ~/tunepile/.venv/bin/python."""
from pathlib import Path
from collections import defaultdict
import re
from music21 import midi

pile = Path('/home/erik/tunepile')
out = []

def parse(rel, tag):
    mf = midi.MidiFile(); mf.open(str(pile / 'midi/groove/groove' / rel)); mf.read(); mf.close()
    length = 32 * mf.ticksPerQuarterNote
    voices = [defaultdict(list) for _ in range(3)]
    for track in mf.tracks:
        tick = 0
        for ev in track.events:
            if ev.isDeltaTime():
                tick += ev.time
            elif ev.type == midi.ChannelVoiceMessages.NOTE_ON and ev.velocity > 0 and 0 <= tick < length:
                n, v = ev.pitch, ev.velocity
                if n in (35, 36):   voice, snd, ceil = 0, 'p70kick', .62
                elif n in (37, 38, 40): voice, snd, ceil = 1, ('p70snare' if v > 90 else 'p70soft'), .55
                elif n in (22, 26, 42, 44, 46): voice, snd, ceil = 2, ('808oh' if n in (26, 46) else 'p70hat'), .32
                else: continue
                voices[voice][tick].append(f's "{snd}" # gain {ceil * (v/127)**.5:.4f}')
    for i, notes in enumerate(voices):
        times = sorted(notes)
        parts = [(times[0], 'silence')] if times and times[0] else []
        for j, t in enumerate(times):
            dur = (times[j+1] if j+1 < len(times) else length) - t
            pat = notes[t][0] if len(notes[t]) == 1 else 'stack [' + ', '.join(notes[t]) + ']'
            parts.append((dur, '(' + pat + ')'))
        body = ', '.join(f'({d}, {p})' for d, p in parts)
        out.append(f'let {tag}_{i} = slow 8 $ timeCat [{body}]')
    print(f'{rel}: ' + str([sum(map(len, v.values())) for v in voices]))

parse('drummer5/session2/21_latin-brazilian-ijexa_108_beat_4-4.mid', 'ijx87')
parse('drummer7/session2/76_funk_100_beat_4-4.mid', 'fnk87')

# Air 'Cherry Blossom Girl' guitar arpeggio -> D major (+5 semitones from its A home).
text = (pile / 'tabs-tidal' / 'Air_-_Air_-_Cherry_Blossom_Girl.gp4-ca8c4ec1.tidal').read_text()
cells = re.search(r'^d1 \$ n "([^"]+)"', text, re.M)[1].split()
pcs = {'c':0,'d':2,'e':4,'f':5,'g':7,'a':9,'b':11}
names = ['c','cs','d','ds','e','f','fs','g','gs','a','as','b']
def shift(tok, semi=5):
    def rep(m):
        letter, sharp, oct = m.groups()
        total = pcs[letter] + (1 if sharp else 0) + semi
        return names[total % 12] + str(int(oct) + total // 12)
    return re.sub(r'([a-g])(s?)(\d)', rep, tok)
mel = ' '.join(shift(c) for c in cells)
out.append(f'let air87 = slow 16 $ n "{mel}"')
print(f'Air line: {len(cells)} cells -> {len(cells)/8:.1f} bars')
Path('/tmp/beat87.txt').write_text('\n\n'.join(out) + '\n')
