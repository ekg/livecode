#!/usr/bin/env python3
"""Run with tunepile's venv: coherent groove and MIDI-derived melodic expression."""
from pathlib import Path
from collections import defaultdict
from music21 import midi

root = Path(__file__).resolve().parents[1]
source = (root / '70.tidal').read_text().splitlines()
performance = Path('/home/erik/tunepile/midi/maestro/maestro-v3.0.0/2015/MIDI-Unprocessed_R1_D1-9-12_mid--AUDIO-from_mp3_12_R1_2015_wav--3.midi')
mf = midi.MidiFile(); mf.open(str(performance)); mf.read(); mf.close()
notes = []
for track in mf.tracks:
    tick, held = 0, {}
    for event in track.events:
        if event.isDeltaTime():
            tick += event.time
        elif event.type == midi.ChannelVoiceMessages.NOTE_ON and event.velocity > 0:
            held[(event.channel, event.pitch)] = (tick, event.velocity)
        elif event.type == midi.ChannelVoiceMessages.NOTE_OFF or (event.type == midi.ChannelVoiceMessages.NOTE_ON and event.velocity == 0):
            start = held.pop((event.channel, event.pitch), None)
            if start and event.pitch >= 60:
                notes.append((start[0], event.pitch, start[1], max(1, tick-start[0])))
# Highest right-hand note at each exact onset; use 32 performed accents.
onsets = {}
for note in notes:
    if note[0] not in onsets or note[1] > onsets[note[0]][1]:
        onsets[note[0]] = note
phrase = sorted(onsets.values())[:33]
assert len(phrase) == 33
velocities = [n[2] for n in phrase[:32]]
gains = [.34 + .35 * (v/127) for v in velocities]
gates = [max(.4, min(.96, n[3] / max(1, phrase[i+1][0]-n[0]))) for i,n in enumerate(phrase[:32])]
lines = ['-- 71: OPEN WINDOWS / IN THE POCKET. 99 BPM, 16-bar call and response.',
         '-- LPViz + Groove MIDI rhythm; Bjork/Radiohead notes with MAESTRO expression.',
         '-- Load sc/samples70.scd, then sc/groove71.scd. Wild 70 is retained.', '']
for line in source:
    if line.startswith('let human70_0_'):
        lines += [line, '']
    elif line.startswith('let love70 ='):
        lines += [line.replace('love70', 'love71').replace('slow 7', 'slow 8'), '']
    elif line.startswith('let place70 ='):
        lines += [line.replace('place70', 'place71'), '']
lines += ['let expression71 = slow 8 $ "' + ' '.join(f'{g:.4f}' for g in gains) + '"', '',
          'let articulation71 = slow 8 $ "' + ' '.join(f'{g:.4f}' for g in gates) + '"', '',
          'setcps (99/240)', '']
lines += [
    'd1 $ (slow 16 $ timeCat [(4, fast 4 $ loopAt 1 $ s "p70drumA" # gain 0.7), (4, fast 4 $ loopAt 2 $ s "p70drumB" # gain 0.7), (8, fast 8 human70_0_0)]) # lpf 18000 # hpf 30 # ddSend 0 # delaySend 0 # delayfeedback 0 # verbSend 0 # room 0', '',
    'd2 $ (slow 16 $ timeCat [(8, silence), (8, fast 8 human70_0_1)]) # hpf 120 # lpf 18000 # ddSend 0 # delaySend 0 # delayfeedback 0 # verbSend 0 # room 0', '',
    'd3 $ (slow 16 $ timeCat [(8, silence), (8, fast 8 human70_0_2)]) # hpf 1400 # lpf 18000 # pan 0.55 # ddSend 0 # delaySend 0 # delayfeedback 0', '',
    'd4 $ silence', '',
    'd5 $ n "<[c3 ~ g3 ~] [c3 ~ ~ as2] [gs2 ~ ds3 ~] [gs2 ~ as2 ~] [f3 ~ c4 ~] [f3 ~ ~ gs2] [as2 ~ f3 ~] [g2 ~ ~ b2]>" # s "dubsub" # gain "0.61 0.49 0.57 0.47" # legato 0.45 # lpf 1100 # ddSend 0 # delaySend 0 # delayfeedback 0', '',
    'd6 $ (slow 8 $ timeCat [(4, fast 4 $ loopAt 2 $ s "p70synthA"), (4, fast 4 $ loopAt 2 $ s "p70synthB")]) # gain 0.46 # hpf 250 # lpf 16000 # cut 6 # ddSend 0.08 # delaySend 1 # delayfeedback 0.2 # ddWow 0 # ddCross 1 # verbSend 0.1', '',
    'd7 $ (slow 16 $ timeCat [(8, fast 8 love71), (8, silence)]) # s "supervibe" # gain expression71 # legato articulation71 # lpf 9500 # hpf 180 # pan (slow 16 $ range 0.38 0.52 sine) # ddSend 0.12 # delaySend 1 # lock 1 # delaytime (3/16) # delayfeedback 0.22 # ddWow 0 # ddCross 1 # verbSend 0.14 # verbT60 3.5', '',
    'd8 $ (slow 16 $ timeCat [(8, silence), (8, fast 8 place71)]) # s "p70rhodes" # gain (0.88 * expression71) # legato articulation71 # hpf 220 # lpf 11000 # pan 0.6 # ddSend 0.1 # delaySend 1 # lock 1 # delaytime (5/16) # delayfeedback 0.2 # ddWow 0 # ddCross 1 # verbSend 0.12', '',
    'd9 $ silence', '',
    'd10 $ struct "t f f f t f f f" $ chop 8 $ loopAt 1 $ s "p70perc" # gain 0.22 # cut 10 # hpf 800 # lpf 16000 # pan 0.3 # ddSend 0 # delaySend 0 # delayfeedback 0', '',
    'd11 $ silence', '',
    'd12 $ silence', '',
]
(root / '71.tidal').write_text('\n'.join(lines))
print('Built 71. MIDI velocities:', velocities)
print('Lead gain range:', min(gains), max(gains), 'articulation range:', min(gates), max(gates))
