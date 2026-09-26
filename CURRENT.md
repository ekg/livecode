# Current jam state — PLAYING / RECORDING

**Live scene: `82.tidal` (LET THE NEW ONE RIDE), 104 BPM, D major.**
Restored after another scsynth exit. Recording: `recordings/jam-20260926-1258.wav`.
Fresh check confirmed 70 incoming events in roughly three seconds and stereo
hardware-output envelopes of 0.0522 / 0.0578. Mixer: `sc/groove71.scd`.
`83.tidal` is an undelivered piano-rewrite draft, NOT the restored live scene.
Do not automatically restart playback merely by reading this file.

Direction: let the newer drum/melodic loops ride; do not cycle back to the older,
played-out sources. Three-, five- and seven-bar parts interlock around the groove.
Keep the approved `78.tidal` CHOICE groove as an independent return point.

## Resume

With the normal project stack running:

1. Execute `sc/samples80.scd` through `tidal_sc`.
2. Execute `sc/groove71.scd` through `tidal_sc`.
3. Evaluate `82.tidal` in order when the listener requests playback.

The file includes its own Haskell definitions. `psrate` is declared locally with
`pF` for the existing SuperDirt pitch-shift effect. Reset cycles before evaluation
if starting the new phrases together is desired; hush does not freeze the clock.

## Recombine these saved states

| Scene | Character / change | Main controls to borrow |
|---|---|---|
| 73 | Original approved LPViz playground: “SICK” | d1/d2 rhythm, d6/d8 loop interplay |
| 74 | “Slick Muffin” checkpoint; octave-down short plucks | d6 articulation/register |
| 75 | Original octave restored; eight-bar breakdown | d1 chop/reorder arc, d6 pluck |
| 76 | Walking quarter-note bass added | d5; requires sc/samples76.scd |
| 77 | Historical intermediate: octave lift, faster bass, human hats, backbeat | d3/d4/d5; d1 slice grouping corrected next |
| 78 | **Approved “CHOICE”**: ringing melody and periodic delay throws | best C-minor full-groove return point |
| 80 | Four-loop D-major chain; Kate Bush/Daft Punk call-and-response | previous key-lift scene |
| 81 | Chopped rotating drum bed plus 3/5/7-bar Rhodes/body-percussion/mandolin parts | saved growth stage |
| 82 | Hold newer drum B and melodic source D; no return to played-out loops | **current live performance** |
| 83 | Eleven-bar broken-piano rewrite, saved after failed dispatch | **unperformed draft**, audition separately |

The base mixer for these recent states is `sc/groove71.scd`: drum group 1.25,
music 1.1, FX 0.8; master low-pass 18k, saturation 0.1, gain 0.8, compressor
slope 0.8 / threshold 0.5, ceiling 0.79. The proposed additional compression
experiment was **not applied** before the listener requested a new song.

These are separate historical snapshots, not an instruction to layer every
scene simultaneously. Each full .tidal scene owns all twelve streams. To remix
one axis, bring over only its stream(s) and necessary definitions/aliases.

## 80's new material

Four one-bar LPViz synth loops, eight bars each, chained for 32 bars. A fixed
`chop 8` plus `bite 8 "0 1 3 2 4 6 5 7"` sits above the chain; its order/density
is not modulated as the source changes.

- 117 BPM D-major source: pitch-shift compensation 117/104.
- 124 BPM D-major source: compensation 124/104.
- 120 BPM A-major source: compensation plus five semitones into D.
- 122 BPM E-major source: compensation minus two semitones into D.

All four durations were checked as one bar. Keys/tempos come from filenames;
pitch compensation is calculated, not a claim of independent pitch analysis.
Exact source paths and aliases are in `sc/samples80.scd`.

Piano: top voice of the opening two transcribed bars from Kate Bush's
`Bush_Kate_-_Wuthering_Heights.gp4-1ae31033.tidal`, transposed down seven
semitones from A to D and stretched to a four-bar phrase. This is the piano
introduction, not a claim of quoting the vocal chorus.

Answer: the first 32 keyboard cells from Daft Punk's
`Daft_Punk_-_Digital_Love.gp4-cb2f3cde.tidal`, played through the C4 cpluck sample
in D major. The two phrases take turns over eight bars. The sampled bass walks
in the new key. Drum/percussion sources from the preceding groove are preserved
and reworked; the human hat part retains its Groove MIDI timing/velocity.

## Recording receipt

Finalized local take:

- `recordings/jam-20260926-1146.wav`
- `recordings/jam-20260926-1146.flac`
- `recordings/jam-20260926-1146.markers.jsonl`

Verified FLAC duration: **1666.666667 seconds (27:46.667)**.
Verified FLAC size: **249,068,111 bytes**. This contains the recovered session,
loop playground, Slick Muffin/CHOICE evolution and the new-key transition.
A CHOICE marker at 1441.8 seconds identifies the pre-transition groove and
commit `b905e1e`. No separate short export was made; the full take is preserved.
Audio stays local (gitignored); composition, mixer recalls, provenance and
listener comments are committed.

Additional finalized take: `recordings/jam-20260926-1242.flac`, verified
619.861333 seconds / 94,633,885 bytes. Plugin wall-clock recording state reported
857.2 seconds, but the server had already exited: actual captured duration is
shorter. WAV and markers are also retained. Do not call the missing time audio.

Recovery at 12:58: re-verified that stranded roots 727372 (sclang wrapper) and
727514 (GHCi) belonged to this Pi process; stopped only those owned trees with
the on-disk PID/start-time-checked helper. `tidal_status` then booted the managed
stack. Recalled samples80 + groove71 and evaluated 82. No competing manual stack
or global process-name kill. Cause of scsynth's exit is still unknown. The loaded
extension still has the stale-helper recovery problem; the committed Pi reload
fix has not yet been activated. Scene checkpoints 81/82/83 are in `a6f3d85`.

Earlier finalized take: `recordings/jam-20260926-1117.flac`, 1356.458667 seconds.
See `sc/RECOVERY-2026-09-26-1146.md` for the earlier audio-server exit and stale
plugin-helper caveat. Do not confuse that failure with an intentional hush.
