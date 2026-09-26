# 73 — OPEN WINDOWS / LOOP PLAYGROUND

**Listener-approved:** “omg what's playing now is SICK.”

This is the exact directly evaluated loop mix that prompted that reaction. Hold
this as a reference, rather than immediately adding more foreground synths.

## Recall

1. `tidal_sc`: execute `sc/samples70.scd`, then `sc/groove71.scd`.
2. Evaluate `73.tidal` in order. No clock reset is necessary for live entry.

The mixer stays open: master cutoff 18k, saturation 0.1, compression slope 0.8,
threshold 0.5, master duck 0.04, gain 0.8, ceiling 0.79. Group gains are drums
1.25, music 1.1, FX 0.8. Drum sends are off; melodic repeats are restrained.

## What is actually playing

- d1: one-bar LPViz drum loop, `chop 8` every eighth cycle.
- d2: second two-bar LPViz drum loop, eight slices, changing Euclidean masks,
  periodic event reversal; high-passed so it complements the main kit.
- d3: indexed icshaker samples, seven-of-sixteen pattern and changing accents.
- d6: two natural two-bar LPViz C-minor synth loops, alternating in pairs.
- d8: quieter, chopped/reversed second synth loop. The angle-bracket Boolean
  pattern alternates whole-cycle availability; it is not an eight-step mask.
- d10: LPViz percussion slices in a 5/4 span, against the grounded main beat.
- d4/d5/d7/d9/d11/d12: silent. No generated bass, sustained lead or vocal collage.

Exact alias-to-source paths are saved in `sc/samples70.scd`. Samples remain in
`~/sounds`; no commercial audio is copied into git.

## Work-in-progress distinctions

- 70 is the busier corpus experiment, retained but not the approved current mix.
- `tools/build_groove71.py` is an unperformed MIDI-expression arrangement draft.
- 72 is the prepared stripped-back Glass Atrium recall; it is not this loop mix.
- 73 is authoritative for the approval above. Its statements were submitted
  directly, not through an arrangement builder.

Recording at approval: `recordings/jam-20260926-1146.wav`, with a checkpoint
marker added after commit. Audio remains local; musical state and source paths
are versioned. Commit future performance changes separately.
