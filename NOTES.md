# NOTES — progress journal

A running, dated log of what we built, what we learned, and what is open.
Not the live jam state (that is `CURRENT.md`) and not the reference docs
(`GUIDE.md`, `THEWAY.md`, `LOOPS.md`, `sc/README.md`).

Conventions:

- One `## YYYY-MM-DD` section per session, **newest first**.
- Keep it honest: what changed, what it measured, what broke, what is unresolved.
- Link scene numbers and commits. Put the *why* here; put the *how* in the file.

---

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
