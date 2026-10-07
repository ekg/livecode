# Audition stack (`sc/audition/`)

A second, headless SuperCollider stack that mirrors the live DSP graph
(`sc/init.scd`) so an agent can stage, measure and audition a candidate deck
without touching the live mix. Frozen contract: `docs/stream-audition.md`.

## Ports and layout

| Thing | Value |
|---|---|
| scsynth (audition) | `57111` |
| sclang / SuperDirt (audition) | `57121` |
| orbits | 24 (4 scene channels × 6 local orbits, same as live) |
| CLI | `~/pi-tidal/tools/audition/audition-ctl` |
| startup file | `~/livecode/sc/audition/audition-startup.scd` |
| Tidal boot | `~/livecode/sc/audition/BootTidal-audition.hs` (SuperDirt `oPort 57121`) |
| graph log | `~/livecode/sc/audition/boot.log` |
| engine / sclang / repl logs | `sc/audition/{engine.log,sclang.log,run/repl.out}` |
| metrics (audition-only) | `~/livecode/sc/audition/metrics.scd` |
| job / report dirs | `sc/audition/{jobs,reports}/` |
| job runner | `~/pi-tidal/tools/audition/job-runner.mjs` |
| systemd unit | `~/pi-tidal/systemd/tidal-audition.service` (disabled by default) |

## Start / stop / inspect

```sh
audition-ctl start      # boot scsynth(57111) + SuperDirt(57121) + a Tidal REPL
audition-ctl status     # parseable: scsynth / superdirt / graph / repl / owned pids
audition-ctl repl       # foreground interactive Tidal REPL against the running stack
audition-ctl run-job f  # send a .tidal file to the background REPL
audition-ctl stop       # terminate ONLY the PIDs this CLI recorded
```

`start` waits for the scsynth port, the SuperDirt port and a `done`, FAIL-free
`boot.log`, then starts the REPL. `stop` signals only the recorded process trees
(never `pkill` by name), so other sclang/scsynth/ghci processes on the box are
untouched.

## Sending a pattern to the audition REPL

The background REPL started by `start` reads commands from a FIFO, so from any
shell:

```sh
echo 'd1 $ s "bd*4"' > ~/livecode/sc/audition/run/repl.in
# or, from a file:
audition-ctl run-job my-pattern.tidal
```

Or open a foreground REPL with `audition-ctl repl` and type at the `tidal>`
prompt. Every event goes to SuperDirt on **57121** only.

## Audition jobs: submit / report / jobs

The frozen job protocol (see `docs/stream-audition.md`) stages a `.tidal` scene
on the audition stack, renders it, measures it, and writes a report — all
without touching the live mix.

```sh
id=$(audition-ctl submit ~/livecode/159.tidal --slot 0 --cycles 8)  # prints the job id
# poll until the render finishes (report exits 3 while still running):
while ! report=$(audition-ctl report "$id"); do sleep 2; done
echo "$report"
audition-ctl jobs            # one line per job: <id> <state> <createdISO> <scene>
```

`submit` returns immediately; the render runs detached on the audition stack
(stdout/stderr: `sc/audition/run/job-<id>.log`). `report` prints the frozen
report JSON and exits 3 until the job is terminal. `jobs` lists jobs newest
first. `report` exits non-zero for an unknown id.

### What the runner does

`audition-ctl submit` writes `sc/audition/jobs/<id>.json` and launches
`tools/audition/job-runner.mjs`, which:

1. parses the scene (`tools/audition/scene-format.mjs`) — `-- @scene` header,
   `{- @sc ... -}` blocks, `let` bindings, `d1..d16` lanes;
2. installs the scene runtime (`pi-tidal/sc/scenes.scd`) in the audition sclang
   so the scene **channel buses** (`~piSceneManager[\buses][slot]`) exist;
3. loads the scene into the audition Tidal REPL at the effective cps (`--cps`
   overrides the declared cps) with every LOCAL `# orbit N` remapped to the
   physical `slot * K + N` (K=6) — exactly the scene-mode remap live;
4. renders `--cycles` cycles, then measures `~masterBus` and the slot's channel
   bus with `sc/audition/metrics.scd`;
5. writes `sc/audition/reports/<id>.json` with every field in the frozen
   schema.

A broken scene (bad Haskell) is detected from the REPL's output and ends
`ok:false` with the compiler error — never a stuck `running` job. If the
audition stack is not running (or the scene does not parse), the job fails
immediately with a clear error.

### Metrics (`sc/audition/metrics.scd`)

Audition-only; the live `sc/spectrum.scd` is never touched. It meters the
master bus plus each requested scene channel bus and reports:

- **bands** — the six overlapping BPF bands (44/95/245/775/2740/8900 Hz,
  rq 1.4) with the same `Amplitude.kr(0.25, 2.5)` follower as
  `sc/spectrum.scd`, normalised to shares of the total (0..1);
- **rms / peak / headroomDb** — broadband; `headroomDb` is dB below full
  scale (`-20·log10(peak)`);
- **dominantHz** — band-energy-weighted spectral centroid;
- **chroma[12]** (Chromagram, share of total) and **key**
  (Krumhansl-Schmuckler over the chroma, e.g. `"D minor"`);
- **dissonance** (SensoryDissonance, 0..1).

Measurement notes:

- The master source is `~masterBus` (pre-master-chain, the same source
  `sc/spectrum.scd`/`~deckScanStart` meter), and each deck is its scene channel
  bus. Both are measured identically, so `master` and `decks[0]` are comparable.
- The key is a best-effort estimate: Chromagram on a percussive full mix is
  noisy, so it can differ from the scene's nominal key by a relative mode
  (e.g. C major vs D dorian). `chroma` and `dominantHz` are the raw evidence.
- Averaged over the render window (followers need audio blocks; a single
  snapshot swings too much — see the `~spectrumReportAvg` note in
  `sc/spectrum.scd`).

### Live comparison

`diffVsLive` reads `sc/audition/reports/live.json` if present (written by lane
4's `tidal_audition snapshotLive`); otherwise `available:false` with a note. The
audition stack never touches the live stack.

### Current scope

`withLive:false` (isolated render) is implemented. `withLive:true` is rejected
with a clear `ok:false` / error rather than faked: the runner writes a
`state:"failed"` report explaining it.

Known limitations of the isolated render:

- The scene's `{- @sc ... -}` block (`scene[\mod]`) and the scene-clock tick are
  **not** executed; the channel mixer runs at its default controls. The orbit
  remap (`slot * K + local`) and the Tidal pattern are applied.
- Jobs are serialized by `sc/audition/run/job.lock` (the audition stack is a
  single sclang + REPL with global meter state); a second job waits its turn.
- The render is real-time: `--cycles N` takes about `N / cps` seconds.


## Isolation guarantees (why the live stack is safe)

- **Ports**: the audition scsynth binds `57111` (sclang itself is launched with
  `-u 57121`, so its OSC listener and SuperDirt share `57121`). `57110`/`57120`
  are never bound.
- **sclang stdin**: launched with stdin on the FIFO `sc/audition/run/sclang.in`
  (opened read-write by sclang), so the job runner can submit SC one physical
  line at a time (`this.executeFile(...)`) without sclang ever seeing EOF. This
  replaced the old `-D` (no input thread): the FIFO keeps it headless.
- **Startup file**: `audition-ctl` launches sclang with
  `XDG_CONFIG_HOME=sc/audition/config`, so sclang loads
  `sc/audition/config/SuperCollider/startup.scd` instead of the live
  `~/.config/SuperCollider/startup.scd` (`-l` does **not** move the startup dir;
  `XDG_CONFIG_HOME` does — verified).
- **Graph logs**: the real `sc/init.scd` is executed through a symlink tree at
  `sc/audition/runtime/home/livecode/sc/`. A compile-time class extension
  (`sc/audition/classes/PlatformAuditionHome.sc`, added via the audition
  `sclang_conf.yaml`) redirects `Platform.userHomeDir` to
  `sc/audition/runtime/home`, so the graph's home-derived artifacts land under
  `sc/audition/`, never in the live `sc/`:

  | graph path | resolves to |
  |---|---|
  | `init.scd` graph root + `boot.log` | `sc/audition/boot.log` (via the mirror’s `boot.log` symlink) |
  | `dub_master.scd` `~meterLog` | `sc/audition/runtime/home/livecode/sc/master-meter.log` |
  | `spectrum.scd` `~spectrumLog` | `.../spectrum.log` |
  | `surface.scd` `~scStatePath` / `ctl.log` | `.../state.scd` / `.../ctl.log` |

  `userAppSupportDir` and `userConfigDir` are separate C++ primitives and are
  **not** affected, so SuperDirt, mi-UGens and the downloaded quarks still load.
- **Engine log**: `sc/audition/scsynth-log.sh` (a private copy of the live
  wrapper) writes `sc/audition/engine.log`; the live `sc/engine.log` is never
  opened by this stack.
- **Process ownership**: `stop` acts only on PIDs recorded in
  `sc/audition/run/stack.pids` and their descendants.

The graph is not modified in any way: `sc/init.scd` and the `sc/*.scd` files it
loads are the live files, read through symlinks.

## CPU expectations

The audition stack runs the **same** graph as live — 24 orbits, each with the
dub delay/reverb/monitor global effect chain, plus the group/aux routing strips,
the `Ndef(\dubMaster)` master chain and the same sample banks. Expect roughly
one full core for scsynth under load and a transient load spike while sclang
compiles and SuperDirt registers banks/defs at boot. Two stacks (live + audition)
therefore want ~2 cores of scsynth headroom; this box has 16. The audition
scsynth is not linked to any physical output or to the `tidal_stream` tap.

## Known follow-up (not v0)

The four home-derived write targets are hardcoded in the graph. The clean
long-term fix is to make the graph root env-overridable in `sc/init.scd`,
`sc/dub_master.scd`, `sc/spectrum.scd` and `sc/surface.scd`, which would retire
the symlink tree. That is a contract/graph change and deliberately out of scope
here.
