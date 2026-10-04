# Riddim Anthem -> Jolene Piano -> Pad Landing

**erik + pi** — live TidalCycles take, 7m34s, 7 movements.

Source: `recordings/jam-20261004-1137.flac` (masters: FLAC, sharing: MP3 320).

| # | start | len | title |
|---|-------|-----|-------|
| 01 | 0:00 | 38.6s | New Space |
| 02 | 0:38.6 | 59.7s | Amen Riddim |
| 03 | 1:38.3 | 54.7s | Go Hard |
| 04 | 2:33.0 | 45.3s | Chopped & Screwed |
| 05 | 3:18.3 | 123.9s | Jolene Piano |
| 06 | 5:22.2 | 84.4s | Breakdown & Rebuild |
| 07 | 6:46.6 | 48.1s | Pad Landing |

## Mastering

**`mastered-smooth/`** is the deliverable:

- `jam-20261004-1137.smooth.flac` (+ `.mp3`) — the whole programme mastered once
  with a smoothly ridden gain curve (`tools/master_smooth.py --target -14
  --ramp 20`): the live take measured **−22.35 LUFS** integrated (TP −10.23 dB)
  and each movement gets its own gain (+9.7 … +14.0 dB from the section table),
  interpolated over 20 s across every join. Largest section-to-section change
  **1.04 LU** over ~20 s — no steps.
- `tracks/` — the seven movements sliced from that single master, so every file
  carries identical processing (FLAC masters + MP3 320).

Chain: `highpass 30 Hz` → glue compression (light 2:1 @ −18 dB, 20/250 ms) →
loudness target → `alimiter` 1.2 dB under the −1 dBTP true-peak target (the
margin is measured from this material: intersample overshoot ~1.1 dB).
Verified per section: **−14.6 … −16.2 LUFS, TP ≈ −2.2 dB**.

Tools: `tools/master_smooth.py` (smoothed continuous ride) and
`tools/make_album.py` (movement slices). Audits: `smooth-report.json`,
`tracks/loudness.json`.

Curated from the take's 22 markers — the full edit history (every `n`-selection
tweak, the amen rebuild, the piano octave-up/reverse) is in
`recordings/jam-20261004-1137.markers.jsonl`.
