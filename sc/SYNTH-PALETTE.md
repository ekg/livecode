# Synth palette — verified 2026-09-26

These names were queried from the **running** `SynthDescLib`, not inferred from
files on disk. Current safe audition: `63.tidal`, piano → vibes → mandolin → FM,
same C-minor phrase at gain 0.5, with a quiet kick. No output-routing changes.

## Already loaded

- Keys / struck / plucked: `superpiano`, `supervibe`, `supermandolin`,
  `supergong`, `superhammond`, `superfork`.
- Analog-style / bass / rave: `supersaw`, `superpwm`, `supersquare`,
  `superreese`, `superhoover`, `superzow`.
- FM / digital / experimental: `superfm`, `superchip`, `supercomparator`,
  `supergrind`, `superhex`, `superprimes`, `superstatic`, `supertron`,
  `superwavemechanics`, `supernoise`, `supersiren`.
- Synthesized percussion: `super808`, `superkick`, `supersnare`, `superhat`,
  `superclap`.
- Project instruments: `dubchord`, `dubsub`, `tapestab`.

`FM7`, `DWGPlucked` and `MembraneCircle` classes are available for new instruments.
`MiPlaits`, `MiBraids` and `MiRings` classes are **not** installed/loaded here.
A UGen being available does not mean a Tidal-compatible SynthDef already exists.

## Community sources worth drawing from

1. [SuperDirt synth reference](https://tidalcycles.org/docs/reference/synthesizers/)
   and [extra definitions](https://github.com/musikinformatik/SuperDirt/blob/develop/library/default-synths-extra.scd).
   The first place to look for the actual controls of the instruments above.
2. [SCLOrkSynths](https://github.com/SCLOrkHub/SCLOrkSynths): reusable community
   SuperCollider instruments with Pattern demos. Not all are drop-in SuperDirt
   instruments; adapt selected voices rather than loading an entire library.
3. [mi-UGens](https://github.com/v7b1/mi-UGens) and the
   [Tidal installation guide](https://tidalcycles.org/docs/reference/mi-ugens-installation/):
   Mutable Instruments ports including Plaits/Braids/Rings. Requires installing
   compiled extensions and loading the appropriate Dirt wrappers; not a hot-load
   of a text SynthDef alone. Defer until a planned maintenance break.
4. [SynthDefs for Tidal](https://club.tidalcycles.org/t/synthdefs-for-tidal/1092):
   community collection/discussion and further sources.

## Safe integration recipe

- Inspect each definition and its license/dependencies; pin provenance.
- Preserve this project's master path: `out` from Dirt, `DirtPan`, and
  `OffsetOut.ar(out, ...)`. Never hardwire output 0 in a source instrument.
- Bound levels and lifetime; ensure envelopes free nodes, and no `SoundIn` or
  feedback/monitor routing is introduced by an imported example.
- Keep controls in `sc/params.tsv`; regenerate both SC/Tidal manifests.
- Hot-load one named `.scd` module via the existing plugin-owned sclang.
- Audition at low gain, verify output and node cleanup, then add to the palette.

References refreshed by web search and source reads on 2026-09-26. No new
packages were installed during this audit.
