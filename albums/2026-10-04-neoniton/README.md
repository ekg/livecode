# Neoniton

*(80s hooks -> hard techno -> pretty return)*

**erik + pi** — live TidalCycles take, 7m41s, 6 movements.

Source: `recordings/neoniton-20261004-1103.flac` (masters: FLAC, sharing: MP3 320).

This is the take that opened the session: 80s hooks mined from `~/tunepile`
(Tears For Fears "Everybody Wants To Rule The World", a-ha "Take On Me", Michael
Jackson "Billie Jean" contour) over a 120 BPM groove, then stripped to a solo
melody, then a new hard techno beat, then a pretty return (Toto "Africa").
The chunk-by-chunk history is in `143.tidal` / `142.tidal` and the marker file.

| # | start | len | title |
|---|-------|-----|-------|
| 01 | 0:00 | 51.8s | Groove In |
| 02 | 0:51.8 | 42.8s | Sweep & Pad |
| 03 | 1:34.6 | 129.2s | Kicks & Skeleton |
| 04 | 3:43.8 | 71.8s | Solo & Dub Delay |
| 05 | 4:55.6 | 36.7s | Hard Techno |
| 06 | 5:32.3 | 129.0s | Pretty Return |

## Mastering

**`mastered-smooth/`** is the deliverable:

- `neoniton-20261004-1103.smooth.flac` (+ `.mp3`) — the whole programme mastered once
  with a smoothly ridden gain curve (`tools/master_smooth.py --target -14
  --ramp 20`). Sections measured −21.8 … −28.9 LUFS (the melody solo is the
  quietest, needing +14.85 dB; hard techno the loudest, +7.76 dB), interpolated
  over 20 s across every join. Largest section-to-section change **3.61 LU** over
  ~20 s — no steps.
- `tracks/` — the six movements sliced from that single master, so every file
  carries identical processing (FLAC masters + MP3 320).

Chain: `highpass 30 Hz` → glue compression (light 2:1 @ −18 dB, 20/250 ms) →
loudness target → `alimiter` 1.2 dB under the −1 dBTP true-peak target.
Verified per section: **−13.4 … −17.0 LUFS, TP ≈ −2.2 dB** (the quiet solo deliberately
sits 3 LU below target rather than pumping).

Tools: `tools/master_smooth.py`, `tools/make_album.py`. Audits:
`smooth-report.json`, `tracks/loudness.json`.
