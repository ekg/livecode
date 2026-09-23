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

Two master passes are kept beside the album:

- `mastered/` — every movement normalised to **-14 LUFS integrated** (the
  streaming/Spotify target), true peak ≤ -1.3 dBTP, glue compression + 30 Hz
  high-pass + limiter. Loudest-to-quietest spread across the original take was
  18 dB (track 10 measured -29.5 LUFS); after this pass the album sits within
  0.28 LU of target throughout. MP3 320 copies included for sharing.
- `mastered-album/` — one gain for the whole record (+1.47 dB, set by the
  loudest movement), so the shape of the performance survives: it keeps the
  quiet lo-fi ending quiet. Use this one when listening start-to-finish.

Pipeline: `tools/master.py` (EBU R128 loudnorm, two-pass linear; `--preset
share|quiet|loud|reference`, `--comp none|light|medium|heavy`, `--album-gain`,
`--measure-only`). Reports in `master-report.json` / `loudness.json`.
