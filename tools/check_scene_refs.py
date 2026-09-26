#!/usr/bin/env python3
"""Find scene files that reference custom names they do not define.

Catches a recurring class of bug: a scene plays only because an earlier eval left the
binding in the REPL, so the .tidal file is not actually self-contained and cannot be
recalled from scratch. This bit us with pian92, samba_*, rhu_snare and air109.

A "custom name" is a lowercase identifier containing a digit (air109, prog107, lpvMel,
sd102, bed85) or an underscore alias (samba_kick, rhu_snare). Tidal builtins are not
listed here, so treat matches as "check by hand" rather than proof of breakage - but a
name defined nowhere and not a declared control is almost always a real omission.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# Sample aliases never need a `let` binding.
SAMPLES = re.compile(r'^(p\d|k808|s808|h808|c808|cb808|cn808|cy808|sh808|t808|h2o|808)')

# d1..d12 are Tidal stream functions, not bindings.
STREAMS = re.compile(r'^d\d+$')
CUSTOM = re.compile(r'\b([a-z][a-zA-Z]*_?[a-zA-Z]*\d+[a-zA-Z0-9]*|[a-z]+_[a-z]+)\b')


def declared_params():
    """Names declared in sc/params.tsv are legal controls, not missing bindings."""
    names = set()
    tsv = REPO / 'sc' / 'params.tsv'
    if not tsv.exists():
        return names
    for line in tsv.read_text().splitlines():
        stripped = line.split('#', 1)[0].strip()
        if not stripped:
            continue
        for tok in stripped.split()[1:]:
            names.add(tok.split(':', 1)[0])
    return names


PARAMS = declared_params()


def defined_names(text):
    """Any `let name =` at any indentation, so do-block locals count."""
    return set(re.findall(r'^\s*let\s+([A-Za-z_][A-Za-z0-9_]*)\s*=', text, re.M))


def referenced_names(text):
    body = '\n'.join(l for l in text.splitlines() if not l.startswith('--'))
    body = re.sub(r'"(?:[^"\\]|\\.)*"', '""', body)   # drop string literals
    return set(CUSTOM.findall(body))


def main(paths):
    bad = 0
    for name in paths:
        text = Path(name).read_text()
        missing = sorted(r for r in referenced_names(text)
                         if r not in defined_names(text)
                         and r not in PARAMS
                         and not STREAMS.match(r)
                         and not SAMPLES.match(r))
        if missing:
            bad += 1
            print(f'{name}: references undefined -> {", ".join(missing)}')
    print(f'checked {len(paths)} file(s); {bad} not self-contained')
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
