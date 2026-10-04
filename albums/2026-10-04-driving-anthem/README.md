# Driving Anthem (tech house riddim)

**erik + pi** — live TidalCycles take, 4m16s, 6 movements.

Source: `recordings/jam-20261004-1133.flac` (masters: FLAC, sharing: MP3 320).

Built live from `143.tidal` in one pass: melody + pad → tech house riddim
(4-on-floor, offbeat hats and bass) → layered/heavier drums and a hard kick →
breakbeat breakdown with double-time drums → bring back → a new ending (pad
moves to Bm–G–D–A, melody softens). Markers record each move.

| # | start | len | title |
|---|-------|-----|-------|
| 01 | 0:00 | 39.3s | Melody & Pad |
| 02 | 0:39.3 | 44.3s | Tech House Riddim |
| 03 | 1:23.6 | 70.3s | Drums & Hard Kick |
| 04 | 2:33.9 | 32.4s | Breakbeat Breakdown |
| 05 | 3:06.3 | 33.7s | Bring Back |
| 06 | 3:40.0 | 36.1s | New Ending |

## Mastering

**`mastered-smooth/`** is the deliverable:

- `jam-20261004-1133.smooth.flac` (+ `.mp3`) — mastered once with a smoothly
  ridden gain curve (`tools/master_smooth.py --target -14 --ramp 20`). Sections
  measured −24.3 … −29.8 LUFS (the closing pad is the quietest, +15.80 dB),
  interpolated over 20 s across every join. Largest section-to-section change
  **0.78 LU** — the smoothest of the day's three takes.
- `tracks/` — the six movements sliced from that single master (FLAC masters +
  MP3 320), so every file carries identical processing.

Chain: `highpass 30 Hz` → glue compression (light 2:1 @ −18 dB, 20/250 ms) →
loudness target → `alimiter` 1.2 dB under the −1 dBTP true-peak target.
Verified per section: **−14.4 … −15.2 LUFS, TP −1.9 … −2.2 dB**.

Tools: `tools/master_smooth.py`, `tools/make_album.py`. Audits:
`smooth-report.json`, `tracks/loudness.json`.
