#!/usr/bin/env python3
"""Extract a melodic 1-bar window from tunepile transcriptions and transpose to D.
Usage: song_lines.py N_TOKENS FILE [FILE...]"""
import re, sys
from pathlib import Path

pile = Path('/home/erik/tunepile/tabs-tidal')
N = int(sys.argv[1])
TONIC = {'c':0,'cs':1,'db':1,'d':2,'ds':3,'eb':3,'e':4,'f':5,'fs':6,'gb':6,
         'g':7,'gs':8,'ab':8,'a':9,'as':10,'bb':10,'b':11}
PCS = {'c':0,'d':2,'e':4,'f':5,'g':7,'a':9,'b':11}
NAMES = ['c','cs','d','ds','e','f','fs','g','gs','a','as','b']

def key_tonic(text):
    m = re.search(r'key ([A-Ga-g])([b#]?)(major|minor|maj|min)', text)
    if not m: return 0
    L, acc, mode = m.groups()
    t = PCS[L.lower()] + (1 if acc == '#' else -1 if acc == 'b' else 0)
    if mode.startswith('min'): t = (t + 3) % 12
    return t

def shift_token(tok, semi):
    def rep(mo):
        L, S, O = mo.groups()
        v = PCS[L] + (1 if S else 0) + semi
        return NAMES[v % 12] + str(int(O) + v // 12)
    return re.sub(r'([a-g])(s?)(\d)', rep, tok)

for name in sys.argv[2:]:
    path = pile / name
    if not path.exists():
        print(f'--- MISSING {name}'); continue
    text = path.read_text()
    semi = (2 - key_tonic(text)) % 12          # target D major
    if semi > 6: semi -= 12                     # nearest direction
    best, best_n = None, -1
    for m in re.finditer(r'^d\d+ \$ n "([^"]+)"', text, re.M):
        toks = m.group(1).split()
        for start in range(0, max(1, len(toks) - N + 1), 4):
            win = toks[start:start+N]
            n = sum(1 for t in win if t != '~')
            if n > best_n:
                best_n, best = n, win
    if not best:
        print(f'--- NO NOTES {name}'); continue
    out = ' '.join(shift_token(t, semi) for t in best)
    print(f'-- {Path(name).stem[:44]}  transpose {semi:+d}  notes {best_n}')
    print(out)
