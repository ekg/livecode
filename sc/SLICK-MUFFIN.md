# SLICK MUFFIN — approved live checkpoint

> “omg what's playing now is SICK.”
>
> “Make sure that where we are right now is recorded, committed, and clear, and
> good. And that I said it was like a slick muffin.”

**Current performance: `74.tidal`.** Previous approved loop mix: `73.tidal`,
commit `467c339`. Do not confuse this checkpoint with the earlier arrangement
builders or sustained-synth experiments.

## Exact recall

With the project's normal SuperDirt/DSP stack running:

1. Execute `sc/samples70.scd` through `tidal_sc` (curated aliases to existing
   user-owned library files).
2. Execute `sc/groove71.scd` through `tidal_sc` (the saved open, drum-forward mix).
3. Evaluate `74.tidal` in order through Tidal. No other scene definitions needed.

There is intentionally no `hush` or clock reset in this file, so recalling it
need not interrupt playback. For a fresh take, reset cycles before evaluation.

## The sound

- Recorded LPViz drum loops, chops and changing Euclidean masks drive the groove.
- Indexed shakers and a 5/4 percussion-slice layer provide motion.
- LPViz C-minor synth loops supply the main melodic material.
- Foreground d6 is now eight slices per two-bar loop, **one octave down**, with
  four alternating gain accents, 4ms attack, 15ms hold and 160ms release.
  This uses SuperDirt's sample amplitude-envelope effect: short plucks rather
  than a continuous flat-level loop. Other streams are unchanged from 73.
- d8 retains the quieter upper chopped/reversed melodic answer.
- No sustained saw lead, generated bass, clak ricochets or vocal collage.

## Mixer

`sc/groove71.scd` restores the full chain through its parent snapshots:

- master gain 0.8, LPF 18kHz, saturation 0.1;
- compressor slope 0.8, threshold 0.5, master duck 0.04;
- master ceiling 0.79; safety filtering/limiting retained;
- group gains: drums 1.25, bass 1.0, music 1.1, FX 0.8;
- dry drums, restrained melodic verb/delay, shimmer return off.

These are saved controls, not a promise that any unrelated future server state
will match without recall. Source aliases and exact absolute file paths are in
`sc/samples70.scd`. Full original loop-mix notes are in `sc/scene73.md`.

## Preservation

The ongoing take at this checkpoint is `recordings/jam-20260926-1146.wav`.
A “Slick Muffin” marker will tie the approved moment to this composition commit.
Finalize to WAV + FLAC, then begin a continuation take without stopping playback.
Audio remains local (gitignored); patterns, mixer, source map and this approval
are committed. A recording receipt records verified finalized file details.

Change policy: preserve this baseline and commit each subsequent musical edit.
