# NOTES — progress journal

A running, dated log of what we built, what we learned, and what is open.
Not the live jam state (that is `CURRENT.md`) and not the reference docs
(`GUIDE.md`, `THEWAY.md`, `LOOPS.md`, `sc/README.md`).

Conventions:

- One `## YYYY-MM-DD` section per session, **newest first**.
- Keep it honest: what changed, what it measured, what broke, what is unresolved.
- Link scene numbers and commits. Put the *why* here; put the *how* in the file.

---

## 2026-10-15 — 175 TILT FLOOR + the master chain dismantled, split, and one real trap

**New scene: `175.tidal` (TILT FLOOR).** Original deep house, 124 BPM (cps 0.51667),
A minor, one cycle = one bar. A SIX-bar harmony (Am9 Fmaj9 Dm9 G9 Cmaj9 E7) so the
phrase never squares up with the 4-bar/8-bar grid; kick E(4,4) is the only lane with no
rotation, and the other lanes sit on different coprime rotations of the 16th grid. Loaded
on deck A; every sample/synth name checked against the live library first
(`rolandtr909`, `drumtraks`, `808bd/oh`, `guira`, `ebongos`, `lpviz`, `sprvibe`,
`dubsub`, `sweetChords`, `superzow`). Compiles and renders over 128 cycles
(`tools/validate_scenes.py` PASS).

**Desk-driven mix fixes (operator was listening the whole time).** "too much kick" -> the
stacked `drumtraks:0` layer and the `sometimesBy 0.07 (fast 2)` double are gone, one 909
voice at gain 0.55. "delay insane" -> lane sends cut to 0 and the master dub delay set to
dWet 0. "it's basssssyy" -> master HPF 34 -> 62, kick HPF 66, bass lane hpf 52 / gain 0.36.

**The master FX were removed, not tuned** (`sc/dub_master.scd` -> two files). The old chain
was `hpf -> dub delay (feedback ring, tanh) -> glue compressor -> tape saturation -> tone
-> kick duck -> soft knee -> limiter`. Every stage was something to be wrong at 2 a.m. The
master is now `hpf -> gain -> clip2`.

**Split, because the old file could not be changed safely.** It allocated `~masterBus` in
its top half, so re-running it handed out new bus indices and the session went silent with
no error. Now:
- `sc/master-bus.scd` - buses + gain + meter. Allocates, so loaded ONCE at boot, never hot-reloaded.
- `sc/master-fx.scd` - `dirt_masterctl` + `~masterFxChain` + `Ndef(\dubMaster)`. Allocates NOTHING,
  so it is re-runnable while the track plays; ships DRY.

**THE TRAP (cost an hour, documented at the top of `master-fx.scd`):** an FX helper whose
feedback ring used `LocalIn.ar`/`LocalOut.ar`, called from inside `Ndef(\dubMaster)`, built
with **no error and produced EXACT silence**: hardware bus 0.0, the Ndef's own meter pinned
at 0.0, while the input bus measured real signal (up to 0.0194). It presents as "the reader
runs before the writers" and as "the scene mixers are muted" - both were checked and both
were FALSE (mixer `mix` = 1.0, orbits -> channel bus -> master all intact, synth count
fluctuating 110->203 so events were arriving). Do not put LocalIn/LocalOut in the master
Ndef; use a bus-based send/return or an acyclic insert.

**Related, and also a trap:** the minimal rebuild used to get sound back dropped the
`Out.kr` meter writes, so the meter read 0.0 again and looked like the same fault. Restored
by re-running `master-fx.scd` + `~masterReTail`.

**`~masterReTail` exists because ordering is not static.** scsynth zeroes internal buses
each control cycle, so the reader must sit after the writers - but in scene mode the writers
are the `piSceneMixer` synths in `~piSceneManager[\group]`, NOT the dirt group that
`init.scd` re-tails into. Re-tail after every scene load / Ndef rebuild.

**Where the "vibrating / crunchy" actually came from**: not the master. `piSceneMixer` runs
`LPF -> (sig * (1 + sat*3)).tanh / (1 + sat) -> + FreeVerb2 * wet`, and 175's `{- @sc -}`
block was sine-modulating `sat` 0.13-0.25, `wet` 0.05-0.19 and `tone` 2000-4400 with three
coprime periods. A modulated reverb into a nonlinearity, on every sample of every bar. 175's
block is now flat `[18000, 0, 0, 1]` and the `shape` values are gone.

**Measured after**: SC-side master rms 0.006-0.052, ceiling-use <= 4%.

**Unresolved:** the level is conservative (ceiling-use under 5%) - raise with
`~masterVol.value(n)`; no level-matched listening pass yet; `tools/vidlearn/` (a venv) is
untracked and deliberately not committed.

## 2026-10-13 — 174 audio-artifact investigation

**Confirmed DSP bug and correction (auditory acceptance still pending)**
- Scene mixer in `~/pi-tidal/sc/scenes.scd` used `1 + sat * 3`. SC binary
  operators have equal precedence, evaluated left-to-right: at sat=0.13 this
  evaluates to **3.39**, not **1.39**. At zero it is **3**, not **1**.
  Thus a roughly 7.74–9.54 dB unintended boost drives the *combined mix* into
  tanh, before the master tape/knee. This generates bass-rate intermodulation
  without the final signal ever reaching full scale.
- Fixed to `1 + (sat * 3)`, with a source regression test. Kept all buses,
  physical links, channel weights, deliberate FX and limiter routing unchanged.
  Installed the corrected SynthDef in the stopped live scene mixers without
  resuming patterns. Positive-sat warmth remains; zero still applies unity-drive
  tanh (not a promised hard bypass), but no longer the erroneous 3x drive.
- Isolated SC two-tone test: 43/86 Hz bass + 997 Hz probe, shared identical input
  for faulty/corrected branches. At bass amplitude 0.1, scene sidebands fall
  **-27.56 -> -42.87 dBc** (15.31 dB improvement); modeled scene/master cascade
  **-11.85 -> -25.69 dBc**. Linear reference below -98 dBc across the sweep.
  This establishes a volume-dependent, 43-Hz-spaced distortion mechanism; it
  does not alone prove the operator's perceived artifact is completely gone.
- 64-second song renders: raw peaks 0.1085 / 0.1097; scene RMS 0.04654 / 0.01919;
  master peaks 0.29437 / 0.15414 (faulty / corrected). Created a **level-matched**
  corrected take (gain 2.3728, peak 0.36574) so listening is not confounded by
  quieter playback. Files: `recordings/diagnostics-174/174-{buggy-audition,
  fixed-audition,fixed-levelmatched}.wav`, `transfer-report.json`, and
  `gain-comparison.json`.
- Tests: 41 scene/controller tests pass; full plugin suite 97 pass / 3 skip /
  1 blocked by missing `typebox` dependency in existing recovery test.
- Also fixed audition isolation: its default JACK identity had auto-linked to
  `tidal_main` contrary to its docs. Stopped it before test patterns; assigned
  `TidalAudition`, `node.autoconnect=false`, cleared SC default port hints, and
  verified **zero external links** before every render. No live links changed.
- Reproduction: isolated `tidal_audition start`, then `python3 tools/diagnose_174.py`.
  `sc/audition/test-mix-transfer.scd` runs only on port 57111; analyze its take
  with `python3 tools/analyze_174_transfer.py`. Playback remains stopped until
  operator approves a short listening check.
- Subsequent authorized playback: operator reports the mix is quiet/muddy and
  **distortion returns despite the precedence correction**. The gain bug is real,
  but the complete audible fault remains unresolved. Requested an adjustable
  master compressor/limiter; those new changes have NOT been applied. Saved
  existing settings in `sc/174-master.scd` as a checkpoint only. At operator's
  latest stop request, shut down the scene, stream, REPL, sclang and scsynth;
  ports 57110/57120 are closed. Leave unrelated microphone recording alone.

- Operator reports a narrow-pulse / crackling artifact around **43 Hz** during
  scene 174. Treat as unresolved synthesis/audio-configuration fault until reproduced
  and localized; the earlier ~35 Hz estimate is NOT a verified output measurement.
- Prior diagnosis corrections: `pw-record --target <sink>` without
  `stream.capture.sink=true` fell back to a microphone. Its clipping and pulse train
  did **not** prove output clipping, extra PipeWire gain, or duplicate master output.
  Ad-hoc summed-channel A2K probes were not true peak meters either.
- Restarted owned SuperCollider/Tidal stack; no PipeWire rewiring. Verified actual
  scsynth rate **48000**, synthesis block **256**, driver quantum **1024**.
  Ndef bus 180 is internal; its monitor routes to hardware 0 normally.
- Correct capture: `pw-record --target <sink-name> --properties
  '{ stream.capture.sink = true }'`; verify both links originate at that sink.
  A 12-second silent headphone-monitor capture peaked at 5.23e-13.
- Controlled 997/1499 Hz stereo tone through the master: scsynth recording and
  verified headphone monitor both peak **0.0231564**, same spectrum/RMS/sample
  deltas; no 20–70 Hz artifact (band power about -204 dB). Transport does not
  exhibit the claimed extra gain in this test.
- Full scene test: 64.98 seconds of overlapping SC/headphone capture, aligned
  by waveform correlation, matched entirely within **1e-7**. Difference RMS
  **8.85e-11**, max **8.85e-8**; equal RMS **0.0287504**, no output clipping.
  Entire SC take peak 0.304534; shorter monitor take peak 0.299981 (different
  coverage, not gain). Largest sample delta 0.02073; no obvious block-edge
  discontinuity concentration. No digital transport fault reproduced this run.
- Low-band peaks vary with the music, not a demonstrated fixed 43 Hz clock.
  Offline Tidal query confirms bass roots a2/g2/f2/e2 send note -27/-29/-31/-32:
  with Dirt's MIDI-60 reference those are A1/G1/F1/E1 (55/49/44/41 Hz).
  The bass's pitch envelope/drive is a candidate only; auditory A/B still needed.
- Evidence copied under `recordings/diagnostics-174/` (verified silent, tone,
  scene monitor WAVs and `diag-scene-comparison.json`); corresponding SC take
  `recordings/diag-scene-174-verified-20261013-1945.wav`.
- Operator confirms audio is **still corrupted after restart**, despite matching
  digital captures. Artifact remains unresolved; matching taps do not establish
  perceptually clean sound. At operator request, stopped deck A, panicked the
  event nodes, and stopped the stream. Do not restart without authorization.
- Evidence: `recordings/diag-controlled-tone-20261013-1944.wav`;
  temporary monitor captures `/tmp/diag-real-monitor-{silent,tone}.wav`.
- Live master restored to dry (dWet=0), sat=0.06, knee=0.75, ceil=0.85;
  eight control-bus slots explicitly set/read back. Do not interpret an immediate
  asynchronous Bus.set/read race as proof of a competing bus writer.

## 2026-10-07

**Toolchain / engine**
- Rebuilt Tidal for the new system compiler: `cabal install --lib tidal-1.10.3`
  on **GHC 9.10.3** (was Tidal 1.10.1 on GHC 9.4.7, which the update removed).
  The Tidal REPL handshake is what broke; SuperDirt was always fine.
- `tools/fix-ghc-env.sh` (new) regenerates the GHC 9.10.3 package env after any
  `cabal install --lib` — cabal's env hides all boot libraries (containers, etc.),
  which red-lit the pi-tidal tests until fixed.
- **scsynth realtime priority enabled.** `tools/scsynth-log.sh` had forced
  `chrt --other 0 prlimit --rtprio=0:0`; denying RT is what pushed PipeWire's
  module-rt onto the rtkit fallback and its 200 ms RTTIME cap. Removed the clamp:
  scsynth is now `SCHED_FIFO`, audio `data-loop.0` prio **83**, RTTIME unlimited.
- Boot self-test **off** (`~selftestEnabled = false`). It fired a `bd` on every
  orbit, and orbits 5-11 map to the music/fx groups whose aux sends are 0.3-0.55,
  so the boot kicks came out reverbed. Re-enable only to hunt a silent mix.

**Metering**
- `sc/spectrum.scd`: added `~orbitScanStart` / `~deckScanStart` + `~orbitScanReport`
  — a compact one-line-per-source readout `label  -NNdB  NNNHz  L/M/H %`, one
  `\piOrbitScan` per source (6 bands + rms + band-weighted centroid).
- Exactly per-**orbit** only in legacy routing; **scene mode bypasses each orbit's
  `dryBus`** (verified: orbit0 out=196 has signal, dry=36 is 0), so there the finest
  view is per-deck (`~deckScanStart`: master + scene channel buses).
- Measured, 118 BPM: 169 master low-end ~62%; 170/171 lower ~52-62%. Still bass-forward.

**Scenes (all 118 BPM / D area so decks mix on one clock)**
- **169 Amber Hours** — lo-fi house. TunePile `lo-fi-loop-...-am7 [d]` = Em9 A9 Dmaj9 Bm9;
  melody = TunePile PD air *Banished to America* (K:D corrected), now at **half time**
  (`slow 8`). Fast-nudge swing on every lane.
- **170 Night Bus** — 8-bar TunePile harmony (ii-V-I-vi | royal-road); sweetChords FM +
  miLead Plaits + dubsub + rolandtr909/guira samples; moistpeace `spreadr`, `rangex`,
  patterned `sometimesBy`, `off`.
- **171 Ghost Machines** — sample-first: rolandtr909 + oberheimdmx + linn9000 layered
  kick walking `bossdr660` bd variants, `akaixr10` perc scanned with `irand`, `end`
  modulation on hats, `p93arp` slice, `lpviz`/`p94brkA` texture.
- **171 rework (in the jam)** — the pad read as a straight, dominating 2-bar drone. Fixed:
  8-bar harmony with secondary motion (ii-V-I-vi | IV-V/vi-ii-V); pad is now RHYTHMIC
  stabs (`struct "<t(3,8) t(4,8) t(5,8) t(6,8)>"`), gain down 0.66 -> 0.54, release 1.8 -> 0.7;
  layered polyrhythm: 3-against-4 chord-tone hemiola (d14, `struct "t(3,8)"`), 5-in-16
  shaker (d15), and the moistpeace `{}%n` polymetric cell `{nperc jamblock ebongos}%16`
  (d16). Verdict: "now we cooking".
- **171 drum pass** — repo sine-drift swing + `swingBy (1/6)` shuffle, ghost kicks, `spreadr`
  fill, extra polymetric hat stream (d10); all drum lanes dry. Scene-mode reverb is a
  deck-wide `FreeVerb2` in `pi-tidal/sc/scenes.scd` (no per-lane send, no delay), so the
  kick is only dry with deck `wet = 0`.
- **Take saved**: `recordings/ghost-machines-171-20261007-0945.flac` (~42 s), wav deleted.
  Verdict: "it's rad". Commit `5d343b0`.

**INCIDENT — piercing high-frequency self-oscillation (fixed)**
- Cause 1 (design): I wired Tidal `m*` to the master by instantiating `dirt_masterctl`
  on orbit 0, writing `~masterCtlBus` with `Out.kr`. A persistent global effect's
  `Out.kr` **adds to a control bus every block** (bus read exactly 4x then 5x the
  defaults). This is why the original m* bridge had been removed. Do not re-add it.
- Cause 2 (trigger): live graph surgery from a `tidal_sc` eval — redefining the
  SynthDef, re-adding the effect, and `freeSynths` — contained `.wait`/`s.sync`,
  which **yield and abort outside a Routine**, leaving duplicated `dirt_dubdelay`
  chains. Their `LocalIn`/`LocalOut` feedbacks summed into a runaway tone.
  `tidal_panic` stopped it; a restart cleared the rogue writer.
- Rules: no `.wait`/`s.sync` in `tidal_sc`; no persistent synth writes a shared
  control bus; structural SC changes go through `tidal_sc_reload`/`tidal_restart`;
  master stays sclang-side (`~masterCtlBus.set` / `~masterSet`).

**Open**
- **Synth-count "leak" explained**: the global FX count is exactly right (24 each), so
  voices are not leaking — the rise is **orphaned orbit-FX nodes from scene rebuilds**
  (each `edit`/`restart` rebuilds 24 orbits x 3 FX). Fix without stopping music:
  `~pruneDirtFX.value` (591 -> 211 synths, 12622 -> 5787 ugens, uninterrupted). Call it
  after scene edits, or cap the number of re-evaluations. `tidal_panic` is the bigger reset.
- `m*` from Tidal: unwired, and unsafe as a global effect. Needs a different design
  (single non-accumulating writer) if wanted.
- Per-orbit metering in scene mode: not available (see above).
- Feels: user wants us to dig deeper into the sample array — multi-sampled drum
  machines, `begin`/`end` scanning, weirder processing — and not lean on the same synths.

**Commits**: `676d0ab` RT+GHC env · `4c05dc8`/`3e9e855` 169 · `d64dd66` 170+171 ·
`779f4ea` scan/boot/bridge · `4883e89` revert m* bridge.
