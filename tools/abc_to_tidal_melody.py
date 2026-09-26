#!/usr/bin/env python3
"""Parse a monophonic ABC tune into a Tidal mini-notation note string on a 16th grid.
Usage: abc_to_tidal_melody.py FILE [transpose_semitones] [tokens_per_bar]"""
import re, sys
from pathlib import Path

path, transpose = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 0
TPB = int(sys.argv[3]) if len(sys.argv) > 3 else 16

text = Path(path).read_text()
body = []
for line in text.splitlines():
    if re.match(r'^[A-Za-z]:', line):        # header
        continue
    body.append(re.sub(r'"[^"]*"', '', line))  # strip chord symbols
body = re.sub(r'!|\\', '', ' '.join(body))
body = re.sub(r'\{[^}]*\}', '', body)         # grace notes
body = re.sub(r'\([A-Za-z0-9^_=,]*\)', '', body)  # guitar chords in parens
body = re.sub(r'[\[\]]', '', body)
body = re.sub(r':?\|+\]?:?', ' ', body)       # barlines / repeats
body = re.sub(r'[Hh]', '', body)              # fermatas

STEPS = {'c':0,'d':2,'e':4,'f':5,'g':7,'a':9,'b':11}
NAMES = ['c','cs','d','ds','e','f','fs','g','gs','a','as','b']
U = 0.5   # one ABC default unit (L:1/8) = half a quarter note = 1/16 grid step
events = []
i = 0
while i < len(body):
    ch = body[i]
    if ch in 'ABCDEFGabcdefg':
        letter = ch.lower()
        octv = 4 if ch.isupper() else 5
        acc = 0
        j = i + 1
        while j < len(body) and body[j] in ',\'^_=':
            if body[j] == ',': octv -= 1
            elif body[j] == "'": octv += 1
            elif body[j] == '^': acc += 1
            elif body[j] == '_': acc -= 1
            elif body[j] == '=': acc = 0
            j += 1
        length, num = 1.0, ''
        while j < len(body) and (body[j].isdigit() or body[j] == '/'):
            if body[j].isdigit(): num += body[j]
            else: length *= 0.5
            j += 1
        if num: length *= int(num)
        if j < len(body) and body[j] in '><': j += 1   # dotted inequality: keep base length
        semis = STEPS[letter] + acc + transpose
        name = NAMES[semis % 12] + str(octv + semis // 12)
        events.append((length * U, name))
        i = j
    elif ch == 'z':
        j = i + 1; num = ''
        while j < len(body) and (body[j].isdigit() or body[j] == '/'):
            num += body[j] if body[j].isdigit() else ''; j += 1
        events.append(((int(num) if num else 1) * U, None))
        i = j
    else:
        i += 1

total = sum(d for d, _ in events)
bars = total / TPB
grid = [None] * (int(round(total)) + 16)
t = 0.0
for dur, name in events:
    if name is not None:
        idx = int(round(t))
        if idx < len(grid): grid[idx] = name
    t += dur
tokens = [g if g else '~' for g in grid[:int(round(total))]]
print(f'total units: {total}  bars: {bars:.2f}  grid: {len(grid)}  notes: {sum(1 for g in grid if g)}')
print(' '.join(tokens))
