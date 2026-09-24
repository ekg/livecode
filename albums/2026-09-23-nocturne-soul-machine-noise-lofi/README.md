# Nocturne Soul -> Machine Noise -> Lo-Fi

**erik + pi** — live TidalCycles take, 35m49s, 10 movements.

Source: `recordings/jam-20260923-1403.flac` (masters: FLAC, sharing: MP3 320).

| # | start | len | title |
|---|-------|-----|-------|
| 01 | 0:00 | 264s | Nocturne Soul |
| 02 | 4:24 | 246s | Warm Breakdown |
| 03 | 8:30 | 145s | Hector the Hero |
| 04 | 10:55 | 133s | Dub Interlude |
| 05 | 13:08 | 342s | Sax Over Boom Bap |
| 06 | 18:50 | 383s | Machine Noise |
| 07 | 25:13 | 151s | Voices in the Factory |
| 08 | 27:44 | 212s | Tresillo Engines |
| 09 | 31:16 | 199s | Lo-Fi Harmonium |
| 10 | 34:35 | 75s | Dissolve |

## Mastering

**`mastered-smooth/`** is the deliverable:

- `jam-20260923-1403.smooth.flac` (+ `.mp3`) — the **whole 36-minute programme**
  mastered once with a smoothly ridden gain curve: each movement gets its own
  level, and the gain is interpolated over 20 s across every join, so there are
  no steps. Whole programme: **-14.6 LUFS integrated, true peak -1.0 dBTP,
  LRA 7.2 LU**; largest glide at a join 2.4 LU spread over ~20 s.
- `tracks/` — the ten movements sliced from that single master, so every file
  carries identical processing.

Measured at the joins (4 s either side): the earlier per-track master stepped by
+1.4 … +3.2 LU; the smooth master changes by -0.4 … +0.6 LU.

Chain in every mode: `highpass 30 Hz` → glue compression (light = 2:1 @ -18 dB,
20 ms / 250 ms) → loudness target → `alimiter` set 1.2 dB below the true-peak
target (the margin is measured from this material: its intersample overshoot is
~1.1 dB, far more than the textbook 0.3 dB).

Two diagnostic masters (per-track normalisation — steps at joins — and a single
album-wide gain — froze the live mix's imbalance) were removed after the smooth
master superseded them. Their numbers are kept in the reports below.

Tools: `tools/master.py` (per-track / `--album-gain` / `--continuous` /
`--measure-only`, presets `share|quiet|loud|reference`, `--comp
none|light|medium|heavy`) and `tools/master_smooth.py` (the smoothed continuous
ride). Audits: `loudness.json`, `mastered-smooth/smooth-report.json`.
