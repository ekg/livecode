#!/usr/bin/env python3
"""Compile and query one-line .tidal scenes without starting an audio stream.
Usage: python3 tools/validate_scenes.py 65.tidal 66.tidal 67.tidal 68.tidal
"""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
commands = [':set -XOverloadedStrings -Wno-type-defaults',
            'import Sound.Tidal.Boot',
            'default (Rational, Integer, Double, Pattern String)']
commands += [line for line in (root / 'BootTidal.hs').read_text().splitlines()
             if line.startswith('let ')]
if len(sys.argv) < 2:
    sys.exit(__doc__)
for index, name in enumerate(sys.argv[1:]):
    streams = []
    for line in pathlib.Path(name).read_text().splitlines():
        if line.startswith('let '):
            commands.append(line)
        match = re.fullmatch(r'd(\d+) \$ (.*)', line)
        if match:
            binding = f'checkedScene{index}Stream{match[1]}'
            commands.append(f'let {binding} = {match[2]}')
            streams.append(binding)
    if not streams:
        sys.exit(f'{name}: no stream statements found')
    commands.append('print (map (\\p -> length (queryArc p (Arc 0 128))) ['
                    + ','.join(streams) + '])')
commands.append(':quit')
result = subprocess.run(['ghci', '-ignore-dot-ghci', '-v0'],
                        input='\n'.join(commands) + '\n', text=True,
                        capture_output=True, cwd=root, timeout=40)
print(result.stdout, end='')
if result.stderr:
    print(result.stderr, file=sys.stderr, end='')
if result.returncode or re.search(r'error:|Exception', result.stdout + result.stderr):
    sys.exit(1)
print('PASS: compiled and rendered every scene over 128 cycles; no audio process started.')
