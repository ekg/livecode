#!/usr/bin/env python3
"""Read audition-only transfer evidence; peaks alone do not test distortion."""
import json
import pathlib
import numpy as np
from scipy.io import wavfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIR = ROOT / 'recordings/diagnostics-174'
rate, audio = wavfile.read(DIR / 'two-tone-transfer.wav')
assert rate == 48000 and audio.shape[1] == 8
rows = []
for index, bass in enumerate([.03, .1, .3, .6]):
    start = int((index * 2 + .5) * rate)
    window = audio[start:start + rate].astype(float)
    spectrum = np.abs(np.fft.rfft(window, axis=0)) * 2 / rate
    sidebins = [997 + k * 43 for k in range(-4, 5) if k]
    sideband = np.sqrt(np.sum(spectrum[sidebins] ** 2, axis=0))
    dbc = 20 * np.log10(np.maximum(sideband, 1e-20) / spectrum[997])
    row = {'bass_input_peak': bass,
           'old_scene_sidebands_dBc': float(dbc[1]),
           'fixed_scene_sidebands_dBc': float(dbc[2]),
           'old_cascade_sidebands_dBc': float(dbc[3]),
           'fixed_cascade_sidebands_dBc': float(dbc[4]),
           'linear_sidebands_dBc': float(dbc[7])}
    rows.append(row)
    print(json.dumps(row))
assert all(r['fixed_scene_sidebands_dBc'] < r['old_scene_sidebands_dBc'] - 8
           for r in rows), 'SC precedence correction must reduce intermodulation'
assert all(r['linear_sidebands_dBc'] < -90 for r in rows)
report = {'test': '43/86 Hz bass plus 997 Hz probe, isolated SC DSP', 'rows': rows,
          'note': 'Confirms a volume-dependent distortion mechanism, not operator auditory acceptance.'}
(DIR / 'transfer-report.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: actual SC render shows reduced 43-Hz-spaced intermodulation, not just lower peaks.')
