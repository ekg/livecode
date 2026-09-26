# GLASS / PRISM / IMPOSSIBLE — live checkpoint

The listener approved this state, including the strange ricocheting, gunshot-like
bursts. Preserve that character: do not silently smooth it away. There are no
explicit gunshot samples in these scenes; rapid clap/clak/snare edits, chip/FM
attacks and layered dub repeats are potential contributors, not an isolated
identification of what the listener heard.

## Recall

With the existing project DSP already running:

1. Through `tidal_sc`: `this.executeFile("/home/erik/livecode/sc/melodic-front.scd");`
2. Through `tidal_eval`: `:script /home/erik/livecode/68.tidal`

The suite is self-contained, resets its clock, and repeats after 128 bars.
The standalone scenes `65.tidal`, `66.tidal`, `67.tidal` can instead be loaded
individually. They replace all twelve streams without restarting the clock.
The routing map is the existing project default: d1–d4 drums, d5 bass,
d6–d8 music, d9–d12 FX. Mixer recall changes controls only; no DSP graph rebuild.

`sc/melodic-front.scd` captures **read-back live controls**, not assumed defaults:

- music group 1.35 (about +3 dB relative to its 0.95 default);
- drums 0.9 (about −0.9 dB); FX 1.05; bass 1.0;
- master duck reduced to 0.08, leaving melodies less suppressed;
- existing aux reverb kick-duck amount 0.65, delay 0.5;
- original FX-group sends and master ceiling retained.

The aux duck is the existing envelope-driven implementation, not a newly
installed compressor. No sidechain DSP rewrite or additional per-note gain boost
was applied after the listener praised this state.

## Form at 102 BPM

| Bars | Time from clock reset | Scene |
|---|---|---|
| 0–31 | 0:00 | Glass Atrium: piano/vibes vapor-soul |
| 32–39 | 1:15 | Eight-bar melodic crossfade, bass exits |
| 40–71 | 1:34 | Prism Choir: brighter pop-house |
| 72–79 | 2:49 | Eight-bar crossfade into chip/FM activity |
| 80–111 | 3:08 | Impossible Arcade: double-time illusion, fractured canon |
| 112–127 | 4:24 | Piano landing; drums return halfway through |
| 128 | 5:01 | Loop |

Intensity is compositional: arpeggio density, contrary motion, register,
reversals, short repeats and percussion edits. The master is not turned up
for the climax. Melodies crossfade; the sub drops out across both bridges.

## Source fragments

These are transformed fragments from local third-party transcriptions, not
commercial master audio or a claim that the arrangements are public domain.
Paths below are relative to `~/tunepile/tabs-tidal/`.

- `Daft_Punk_-_Something_About_Us.gp4-7d5542b2.tidal`: keyboard F–A–D,
  G–A–C, A–C–E, G–B–D voicings expanded over Bb/A/D/G bass roots;
  D–F–D–F–A–C response fragment raised an octave and played on vibes.
- `Spears_Britney_-_Everytime.gp4-dd531691.tidal`: opening C–E–G–E–C–G–E–G
  shape moved to D and made minor, redistributed into a piano answer. The arcade
  version adapts that contour to each chord rather than retaining a fixed key.
- `Madonna_-_Like_A_Prayer.gp4-272dfc51.tidal`: F–F–F–E / F–G–E–F–E vocal
  fragment, condensed and re-rhythmicised as a synth melody over F/C/Dm/Bb.
- `Tears_For_Fears_-_Everybody_Wants_To_Rule_The_World.gp4-ad059e35.tidal`:
  F#–A–F#–B motif transposed +3 semitones into the relative-minor/major palette.
- `Daft_Punk_-_Aerodynamic.gp3-81576607.tidal`: four guitar arpeggio cells
  transposed +3 semitones to Dm/Bdim/Gm/C, revoiced as chip synthesis and
  reversed/doubled periodically. Counterpoint and drum production are new.

The inspected Depeche Mode transcription was not used.

## Editing and validation

Edit standalone scenes first, then regenerate the suite:

```sh
python3 tools/build_scene_suite.py
python3 tools/validate_scenes.py 65.tidal 66.tidal 67.tidal 68.tidal
python3 tools/check_tidal.py 65.tidal 66.tidal 67.tidal 68.tidal
```

Validation compiles expressions in the installed Tidal and renders 128 cycles
without starting a scheduler or SC. All streams are single-line chunks.
No unavailable `arrange` helper is used. Live checks confirmed OSC events,
stereo hardware-bus signal, and the suite's instruments in the running server.
An unavailable `rim` sample was replaced with the verified `clak` bank before
this checkpoint. Continuous live refresh used the same generated suite with
only `resetCycles` omitted, to preserve musical position.

## Recording and versioning

- Previous exploratory take: `recordings/jam-20260926-1054.wav` (+ FLAC/markers).
- Suite take: `recordings/jam-20260926-1117.wav`, recording at this checkpoint.
- Audio stays in local recordings (gitignored); composition, mixer and sources
  are versioned. Recording markers include git HEAD for future correlation.
- Commit each subsequent musical/mixer revision; do not leave live-only changes
  undocumented. pi-tidal and tunepile were clean at this checkpoint.
