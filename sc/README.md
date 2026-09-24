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
