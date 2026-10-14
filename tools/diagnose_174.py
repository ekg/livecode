#!/usr/bin/env python3
"""Record simultaneous audition-only nonlinear DSP taps; never start live audio."""
import json
import os
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUN = ROOT / 'sc/audition/run'


def send(name, text):
    fd = os.open(RUN / name, os.O_WRONLY | os.O_NONBLOCK)
    try:
        os.write(fd, (text + '\n').encode())
    finally:
        os.close(fd)


def wait_file(path, seconds):
    end = time.monotonic() + seconds
    while not path.exists():
        if time.monotonic() > end:
            raise TimeoutError(str(path))
        time.sleep(.2)


# Fail closed if the supposedly headless JACK client has any audio links.
j = json.loads(subprocess.check_output(['pw-dump']))
nodes = [o['id'] for o in j if o['type'].endswith(':Node')
         and o.get('info', {}).get('props', {}).get('node.name') == 'tidal_audition']
assert len(nodes) == 1, 'isolated audition node missing'
assert not any(o['type'].endswith(':Link') and
               (o['info']['input-node-id'] in nodes or o['info']['output-node-id'] in nodes)
               for o in j), 'audition is connected; refusing to play'
print('ISOLATION VERIFIED', flush=True)
ready, done = RUN / 'diag174.ready', RUN / 'diag174.done'
lock = RUN / 'job.lock'
lock.mkdir()  # same mutex as audition job-runner; fail rather than overlap
try:
    (lock / 'pid').write_text(str(os.getpid()))
    for p in (ready, done):
        p.unlink(missing_ok=True)
    source = ROOT / 'sc/audition/diagnose-174.scd'
    send('sclang.in', f'this.executeFile({json.dumps(str(source))});')
    wait_file(ready, 20)
    expression = subprocess.check_output(['node', '--input-type=module', '-e', '''
import fs from 'node:fs';
import {parseScene, patternExpression} from '/home/erik/pi-tidal/tools/audition/scene-format.mjs';
console.log(patternExpression(parseScene(fs.readFileSync('174.tidal', 'utf8')), 0));
'''], cwd=ROOT, text=True).strip()
    send('repl.in', 'setcps 0.5166666666666667')
    time.sleep(.3)
    send('repl.in', 'getnow >>= \\now -> let start = fromInteger (ceiling now + 2) in '
         f'(p "diag174" $ rotR start $ {expression}) >> writeFile {json.dumps(str(done))} "loaded"')
    wait_file(done, 20)
    print('RENDERING 64 SECONDS', flush=True)
    time.sleep(64)
finally:
    try:
        send('repl.in', 'hush')
        send('sclang.in', 'if(~diag174Recorder.notNil) { ~diag174Recorder.free }; '
             'if(~diag174Buffer.notNil) { ~diag174Buffer.close; ~diag174Buffer.free }; '
             '"DIAG174 STOPPED".postln;')
    finally:
        (lock / 'pid').unlink(missing_ok=True)
        lock.rmdir()
time.sleep(1)
print('DONE: recordings/diagnostics-174/nonlinear-taps.wav', flush=True)
