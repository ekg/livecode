# 70 — OPEN WINDOWS

A sample-led departure from the synth-only scene suite. Load `sc/samples70.scd`,
then `sc/open70.scd`, then `70.tidal` through the running plugin. Reset the Tidal
clock first if starting at the beginning; the file itself permits continuous
updates without a reset.

## Actual corpus material

- LPViz `2020_DD_96_DrumLp2.wav`: measured 2.5 seconds, one bar at 96 BPM;
  `loopAt 1` at the new 99 BPM clock.
- LPViz `2020_DD_99_DrumLp6.wav`: measured 4.848 seconds, two bars at 99;
  `loopAt 2`, then `chop 16` and changing Euclidean masks.
- LPViz `2020_DD_99_SynthLp2_Cmin.wav` / `SynthLp3_Cmin.wav`: measured two-bar
  loops, remain at native 99 BPM so their pitch and length agree.
- LPViz `2020_DD_123_PercLp26.wav`: one bar; chopped and played in a 5/4 span.
- `humanip/hmmm mmm.wav`: chopped voice in a 7/4 span.
- `jrhodes/jRhodes Mezzo Piano D4.wav`: pitch-shifted Rhodes samples play the
  Radiohead transcription. Assumed standard filename root MIDI 62; this root
  has not been independently pitch-measured.
- `cpluck/11_body_low.wav`, `coffee` and `icshaker`: rotating sample indices,
  5/4, 7/4 and 3/2 phrase lengths with Euclidean structures.

Sample aliases reference the user's existing files in `~/sounds`; audio is not
copied into git. Existing names are unaffected. Samples retain their original
licenses; this project does not claim ownership of those recordings.

## Human drums, not manufactured swing

Magenta Groove MIDI Dataset, drummer1/eval_session (CC-BY 4.0):

- `10_soul-groove10_102_beat_4-4.mid`: 25 kicks, 32 snares, 65 hat events.
- `2_funk-groove2_105_beat_4-4.mid`: 39 kicks, 63 snares, 69 hat events.
- `6_hiphop-groove6_87_beat_4-4.mid`: 54 kicks, 17 snares, 115 hat events.

Each excerpt is the first eight bars. The generator reads raw MIDI ticks through
music21, not a quantised score: relative microtiming is preserved with weighted
`timeCat` durations. Velocity is mapped monotonically to gain; quieter snare hits
use the soft sample. Groove-specific hat edge notes 22/26 are mapped explicitly.
These are **three performances by one drummer**, not three different drummers.
Their beat-relative timing is rescaled to the session tempo.

The 48-bar drum form alternates eight-bar stretches of recorded LPViz loops,
soul performance, chopped LPViz, funk performance, masked LPViz and hip-hop
performance. The first three streams change together, rather than stacking
several full kits indiscriminately.

## Longer transcribed melodies

Paths relative to `~/tunepile/tabs-tidal/`:

- `Bj_rk_-_All_Is_Full_Of_Love.gp4-97acf1f1.tidal`, d4 cells 144–255
  (zero-based, end exclusive 256): the actual vocal passage, not the opening
  track's high-pitched FX. Transposed down five semitones to C minor. Seven-bar
  phrase; inferred holds are capped at seven following cells because the
  conversion contains onsets, not original note durations.
- `Radiohead_-_Everything_in_its_Right_Place.gp3-f0bed302.tidal`, d1 cells
  0–63: a four-4/4-bar keyboard excerpt from the 2/4 transcription. E and A are
  flattened for the C-minor mashup, moved up an octave and rendered as sample
  transpositions relative to the Rhodes root. This is an adaptation, not an
  unaltered performance of the song.

The 7-bar melody, 4-bar keyboard, 48-bar drums and odd-length sample parts phase
against one another. Bass/harmony choices and sample treatment are new.

## Open mix

`sc/open70.scd` retains the working routing and limiter ceiling. It opens the
master low-pass from 11k to 18k, reduces saturation 0.28 → 0.1, reduces master
compression, and removes drum aux sends. The dry drum patterns explicitly set
18k cutoff. Melodic loop filtering is opened to 16k. This is a deliberate
processing change, not a claim that the previous darkness came only from the
samples. Existing low-frequency safety high-pass and limiter remain.

## Build / validate

```sh
/home/erik/tunepile/.venv/bin/python tools/build_corpus70.py
python3 tools/validate_scenes.py 70.tidal
python3 tools/check_tidal.py 70.tidal
```

The generator needs music21 from tunepile's existing venv. Patterns were compiled
and rendered offline before live submission. Previous scenes 65–69 remain intact.
