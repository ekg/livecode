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

## Adding a parameter, effect or instrument (the recipe)

Built so it needs no thought and cannot be done half-way:

**Adding a Tidal-reachable parameter:**
1. add the name to the right group line in **`sc/params.tsv`** (`name` or `name:f|i|s`)
2. run **`tools/sc_params.py`** — regenerates the `let` block in `BootTidal.hs`
   and `sc/params_gen.scd`
3. restart the Tidal REPL (the boot file is read only at spawn): `tidal_repl`
   tool, or `ps -eo pid,args | awk '/ghci-scri/ {print $1}' | xargs kill`
4. in SuperCollider, either use it in a SynthDef you are already editing, or add
   it to that effect's list in `sc/init.scd`

**Adding an effect:** write the SynthDef in `sc/dub_fx.scd` (global effects are
looked up as `name ++ numChannels`, per-event modules as bare `name`), add a line
to `params.tsv`, add a `GlobalDirtEffect` to `sc/init.scd`, restart sclang
(`pkill -x sclang`, respawns on the next eval) — or use `tidal_sc` to
`this.executeFile` it live once the plugin is reloaded.

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
REPL (`tidal_repl`). Do not assume an earlier `pkill` worked: the binary is
`ghc-9.4.7`, so match the boot file on the command line:

    ps -eo pid,args | awk '/ghci-scri/ {print $1}' | xargs -r kill

and confirm it is gone with `ps -eo pid,comm | awk '$2 ~ /^ghc-/'` (this exact
mistake — a `pkill -x ghci` that silently matched nothing — meant a REPL loaded
on Sep 20 was still serving evals days later).

## The `m*` master params are inert (by design)

`mGain mGlue mSat mCut mDuck mHpf mThresh mWidth` are declared in Tidal (so any
pattern or old chunk referencing them still compiles) but they do **not** reach
the audio: the Tidal -> control-bus -> Ndef bridge was removed after it proved
unreliable (see pi-tidal/docs/sc-effects-and-routing.md). The master chain is
configured in `sc/dub_master.scd`.

So: a pattern using `mGain` will run and simply not change the level. If master
control from Tidal matters later, rebuild it as a plain `Synth` reading the bus
that writes `Ndef` controls — do not bake the bus index into the Ndef's function.
