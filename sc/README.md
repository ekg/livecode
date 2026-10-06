# sc/ — the SuperCollider DSP layer

Loaded automatically by `superdirt_startup.scd` on every stack boot (which the
pi-tidal plugin does lazily). See `~/pi-tidal/docs/sc-effects-and-routing.md` for
the architecture and the gotchas.

- `dub_fx.scd` — dub delay (filtered/saturated feedback, ducking), dub reverb
  (HPF'd send, pre-delay, JPverb with fast low-band decay), per-event tape module,
  instruments `dubchord` `dubsub` `tapestab`
- `dub_master.scd` — master bus, control bus, `dirt_masterctl` param bridge,
  `Ndef(\dubMaster)` chain (hpf → glue+duck → tape → tone → limiter)
- `selftest.scd` — boot-time instrument level check
- `init.scd` — wires it all into SuperDirt, logs to `boot.log`

From Tidal: `# orbit N` for grouping; `dd*` delay, `verb*` reverb, `m*` master,
`tape*` lo-fi module params. Instruments take their pitch in `n` (not `note`).

## Offline checks must not contact the live server

Do **not** launch bare `sclang` as an "offline" syntax test while this stack is
running. Its default localhost server uses UDP **57110**, the live server's
port, and interpreter shutdown can send `/quit` to that server. An attempted
worker stub check may have caused a stack restart this way. A file in `/tmp`
is not process/network isolation.

Use parser and pure `runghc`/`queryArc` checks for offline Tidal validation.
SC tests require a genuinely isolated startup/configuration and server port,
or an explicitly authorized check through the existing `tidal_sc` transport.
Do not boot, restart or evaluate live patterns just to validate a draft.

## Orbit count and scene channels

SuperDirt's orbit count is fixed when it boots, from the out-bus list in
`superdirt_startup.scd`: `~dirt.start(57120, 0 ! (channels * orbits))`. It is
currently **24** (4 scene channels x 6 local orbits).

- `sc/scene-mixer.json` declares the same geometry (`{"channels":4,"orbits":6}`)
  and is what the pi-tidal plugin reads (env vars `PI_TIDAL_SCENE_CHANNELS` /
  `PI_TIDAL_SCENE_ORBITS` override it; default 2 x 6).
- Scene mode gives each channel six *consecutive* orbits (channel 0 -> 0-5,
  channel 1 -> 6-11, ...), re-pointing them at that channel's mixer bus.
- `sc/routing.scd` maps **every** orbit to a group bus (the 12-block repeats for
  higher indices); an unmapped orbit bypasses group processing entirely, which
  is the "two-tier mix" trap.
- The boot self-test fires one event per orbit, so 24 orbits means a slower boot
  and ~72 per-orbit FX synths. Change the number in both files together and
  restart the stack — the plugin refuses to install the mixer if the running
  server has too few orbits.

## Measuring the mix (not guessing it)

`sc/spectrum.scd` answers "who owns the low end?" with numbers. Broadband RMS
cannot see that a kick is 80% of the energy — it only sees that the total is loud,
which is exactly why a sub-heavy kick keeps overwhelming mixes here.

```supercollider
this.executeFile("/home/erik/livecode/sc/spectrum.scd");
~spectrumStart.value;    // meters master + every live scene channel bus
// wait a moment: the Amplitude followers need audio blocks to build up
~spectrumReport.value;   // also appends the table to sc/spectrum.log
~spectrumStop.value;     // free the meter synths when done
```

Bands are sub 30-60, bass 60-150, lowmid 150-400, mid 400-1.5k, highmid
1.5-5k, top 5k-16k, plus a broadband RMS per source. Separately metering each
scene **channel** is the point: when several tracks play at once it shows which
one is hogging the low end, which the master's own meter can never tell you.

Worked example from `152-techno-mashup.tidal` — kick `hpf 46 -> 95` and a shorter
release changed the master's band shares from `81 15 2 1 0 0` to `31 43 19 5 2 1`.

Two honest caveats:

- **No A-weighting.** Energy shares naturally favour bass — real music usually has
  most energy down low, so treat the numbers as *relative* feedback (did it move?)
  rather than absolute targets. A rule of thumb that has held here: a kick whose
  sub band exceeds ~50% of band energy is dominating, and its `hpf` is usually the
  reason. Raising `hpf` moves energy from sub into bass/low-mid without losing punch.
- The master's absolute dB column comes from the project's existing `~meterBus`,
  which is a slow follower and reads low/unstable — trust the band *shares* and the
  ceiling-use warning, not that dB figure.

Remember the coupling that makes kicks doubly dangerous: **orbit 0's dry bus is the
master's sidechain detector**, so a loud orbit-0 kick ducks every other channel.
Fixing the kick's spectrum therefore also buys back headroom for everything else.

## Adding a parameter, effect or instrument (the recipe)

Built so it needs no thought and cannot be done half-way:

**Adding a Tidal-reachable parameter:**
1. add the name to the right group line in **`sc/params.tsv`** (`name` or `name:f|i|s`)
2. run **`tools/sc_params.py`** — regenerates the `let` block in `BootTidal.hs`
   and `sc/params_gen.scd`
3. restart the Tidal REPL with `tidal_repl` (the boot file is read only at
   spawn); do not kill unrelated interpreters
4. in SuperCollider, either use it in a SynthDef you are already editing, or add
   it to that effect's list in `sc/init.scd`

**Adding an effect:** write the SynthDef in `sc/dub_fx.scd` (global effects are
looked up as `name ++ numChannels`, per-event modules as bare `name`), add a line
to `params.tsv`, add a `GlobalDirtEffect` to `sc/init.scd`, then apply it with
`tidal_sc_reload` when a live routing change is authorized. If a full restart
is necessary, use `tidal_restart`, which owns process teardown and REPL
reconnection; never use a blind `pkill`.

**Verification is built in.** `sc/boot.log` records every boot: which SynthDefs
exist, the measured level of each instrument, and whether the master chain passes
audio. Check it after any change — silence with no error is the failure mode this
exists to catch.

Traps worth not re-learning: the REPL binary is `ghc-9.4.7` (so `pkill -x ghci`
does nothing); a multi-line `let` in a ghci script is silently dropped; `if`
cannot take a UGen condition in a SynthDef; mono `In.ar`/`LocalIn` return a bare
UGen; pass bus *indices* not `Bus` objects; custom synths take pitch in `n`, not
`note`.

### If a parameter is "not in scope" again

The running REPL is long-lived and holds whatever `BootTidal.hs` contained when
it was spawned. If only *some* params are missing, the REPL predates the current
file — declare them live (`tidal_param`, or `let x = pF "x"`), or restart the
REPL (`tidal_repl`). The binary is `ghc-9.4.7`, not `ghci`; an earlier
`pkill -x ghci` silently missed it and left an old boot file running for days.
Use the owned restart tool rather than process-name guesses.

## The `m*` master params are inert (by design)

`mGain mGlue mSat mCut mDuck mHpf mThresh mWidth` are declared in Tidal (so any
pattern or old chunk referencing them still compiles) but they do **not** reach
the audio: the Tidal -> control-bus -> Ndef bridge was removed after it proved
unreliable (see pi-tidal/docs/sc-effects-and-routing.md). The master chain is
configured in `sc/dub_master.scd`.

So: a pattern using `mGain` will run and simply not change the level. If master
control from Tidal matters later, rebuild it as a plain `Synth` reading the bus
that writes `Ndef` controls — do not bake the bus index into the Ndef's function.
