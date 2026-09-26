#!/usr/bin/env python3
"""Find scene files that reference custom names they do not define.
Catches the recurring class of bug: a scene plays only because an earlier eval left
the binding in the REPL, so the file is not actually self-contained.

A "custom name" is a lowercase identifier containing a digit (air109, prog107, lpvMel,
sd102, tffTheme, samba_kick...) or an underscore-separated alias (samba_kick, rhu_snare).
Tidal builtins and sample names are excluded.
"""
import re, sys
from pathlib import Path

def declared_params():
    """Names declared in sc/params.tsv are legal controls, not missing bindings."""
    names = set()
    for line in Path(__file__).resolve().parents[1].joinpath('sc/params.tsv').read_text().splitlines():
        line = line.split('#', 1)[0].strip()
        if not line or line.startswith('\t'):
            continue
        for tok in line.split()[1:]:
            names.add(tok.split(':', 1)[0])
    return names

PARAMS = declared_params()
SAMPLES = re.compile(r'^p\d|^k808|^s808|^h808|^c808|^cb808|^cn808|^cy808|^sh808|^t808|^h2o|^808|^d\d+$')
CUSTOM = re.compile(r'\b([a-z][a-zA-Z]*_?[a-zA-Z]*\d+[a-zA-Z0-9]*|[a-z]+_[a-z]+)\b')

def defined_names(text):
    names = set()
    for m in re.finditer(r'^let\s+([A-Za-z_][A-Za-z0-9_]*)', text, re.M):
        names.add(m.group(1))
    return names

def referenced_names(text):
    body = '\n'.join(l for l in text.splitlines() if not l.startswith('--'))
    body = re.sub(r'"(?:[^"\\]|\\.)*"', '""', body)      # drop string literals
    return set(CUSTOM.findall(body))

bad = 0
for name in sys.argv[1:]:
    text = Path(name).read_text()
    defined = defined_names(text)
    refs = referenced_names(text)
    missing = sorted(r for r in refs
                     if r not in defined and r not in PARAMS and not SAMPLES.match(r))
    if missing:
        bad += 1
        print(f'{name}: references undefined -> {", ".join(missing)}')
print(f'checked {len(sys.argv)-1} file(s); {bad} not self-contained')
