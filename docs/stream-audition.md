# Low-latency stream + audition stack — contract v0

Status: **v0, frozen for lanes 1–2.** Lanes 3–4 (metrics, plugin tools) are
stubs here and will be frozen after lanes 1–2 land. Change this file before
changing an interface; two lanes code against it in parallel.

## Goals

1. **Stream**: low latency (~100–250 ms), simple, drift-bounded, toggleable.
   Access is via a Tailscale tailnet now; the same daemon must run on a
   headless server later with no pi present.
2. **Audition**: a second, headless SuperCollider stack mirroring the live
   DSP graph, where agents stage a candidate deck, measure it, and only then
   commit it to the live mix through the existing pi-tidal scene mixer.

Non-goals for v0: Opus, Icecast/HLS, WebRTC, per-listener auth beyond a token,
public-internet hardening, metrics/harmonic analysis (lane 3).

## Architecture

```
scsynth ──JACK──► tidal_stream (Audio/Sink, monitor, NOT auto-linked to physical)
                      │
                      │  pw-record --target tidal_stream --format s16 --rate 48000 --channels 2 \
                      │            -P '{"stream.capture.sink":true}' -
                      ▼
                  streamd (Node)  ── WS binary, 20 ms frames, bounded drop-oldest
                      ▼
                  browser: AudioWorklet ring buffer + adaptive fill controller
```

Separately, headless and independent:

```
sclang(57121) ──► scsynth(57111) ──► SuperDirt(2, s) + sc/init.scd graph
     ▲                                          ▲
     │ job files                                │ audit tap -> its own sink
  sc/audition/jobs/*.json                sc/audition/reports/*.json
```

## Frozen interfaces

### Names, paths, ports

| Thing | Value |
|---|---|
| Tap sink node name | `tidal_stream` (must expose a monitor capturable by `pw-record --target tidal_stream` **with** `-P '{"stream.capture.sink":true}'`) |
| Sink setup | `tools/stream/sink-setup.sh create` = DETACHED, returns once the node is up; `create-fg` = foreground for systemd; `destroy` = idempotent teardown |
| Stream WS port | `8787` |
| Audition scsynth port | `57111` |
| Audition sclang / SuperDirt port | `57121` |
| `streamd` source | `~/pi-tidal/tools/stream/streamd.mjs` |
| stream CLI | `~/pi-tidal/tools/stream/stream-ctl` |
| player page | `~/pi-tidal/tools/stream/player.html` |
| audition CLI | `~/pi-tidal/tools/audition/audition-ctl` |
| audition job dir | `~/livecode/sc/audition/jobs/` |
| audition report dir | `~/livecode/sc/audition/reports/` |
| audition runtime | `~/livecode/sc/audition/audition-startup.scd` (+ `classes/` for the `Platform.userHomeDir` override, `config/` for the XDG startup, `runtime/` for the generated symlink mirror) |
| systemd units | `~/pi-tidal/systemd/tidal-stream-sink.service`, `tidal-stream.service`, `tidal-audition.service` |
| config | `~/.config/tidal-stream/config.json`, overridable by `PI_TIDAL_STREAM_*` env |

Ports/paths are **not** hardcoded twice: `stream-ctl` and `audition-ctl` read
the config file and pass values explicitly.

### Packet framing (WS binary, server → client)

All integers little-endian. One WS message = one frame.

```
offset 0  uint32   seq            monotonically increasing, wraps at 2^32
offset 4  float64  sentMs         server wall clock (Date.now()) at read
offset 12 uint8    flags          bit0 = discontinuity (capture restarted)
offset 13 ...     payload        s16le interleaved stereo, exactly
                                  960 samples/channel = 1920 samples = 3840 bytes
```

Frame = **20 ms @ 48 kHz**. Total message 3853 bytes. No client → server
traffic is required except the token handshake; the client may send a 1-byte
ping and the server replies with the current `seq` (used for explicit resync).

### Server queue discipline (the core anti-drift rule)

Per WS connection the server holds **at most 2 frames**, **drop-oldest**. The
server never grows a backlog for a slow reader. A lagging client loses audio;
it never accumulates latency. `streamd` is otherwise stateless and always
broadcasts the newest frame.

### Client playout contract

- Ring buffer, adaptive target fill `Fₜ = clamp(3 × jitterEst, 60ms, 250ms)`.
- `F_max = Fₜ + 80ms`, `F_min = 20ms`.
- fill > `F_max` → **drop oldest** to `Fₜ` (this is "requeue").
- fill > `Fₜ + 20 ms` → **slow convergence**: drop one 20 ms frame, at most one
  per 400 ms, until back within one frame of `Fₜ`. Without this rule the client
  can only shed latency above `F_max`, so a one-off disturbance (a capture
  restart, a network hiccup) leaves the playout parked anywhere in
  `(Fₜ, F_max]` permanently — fill cannot fall on its own, because consumption
  only matches production. Frame-aligned drops match the server's granularity
  and are the least audible way to shed latency. VERIFIED: after a killed
  capture, fill went from stuck at 105.7 ms to 43.5 ms, with the drop counter
  settling (no continuous trickle).
- fill < `F_min` → silence-pad and refill to `Fₜ` (this is "restart").
- `flags.discontinuity` set → hard resync: flush, refill to `Fₜ`.
- Jitter estimate = EWMA of `(arrivalMs - previousArrivalMs)` deviation,
  α = 0.05; recomputed per frame.

### Supervisor (server-side, the other failure mode)

- no `pw-record` bytes for > 500 ms → kill and restart capture, set
  `discontinuity` on the next frame.
- `tidal_stream` node absent or SuperCollider not linked → re-run the
  fan-out link step, log, keep serving (silence) rather than exiting.
- scsynth gone → stream stays up, emits nothing, and `stream-ctl status`
  reports `source: down` so a human/agent can act.

### Toggle / configuration

`config.json` (missing file = all off):

```json
{
  "enabled": false,
  "bind": "0.0.0.0",
  "port": 8787,
  "token": "",
  "format": "s16",
  "rate": 48000,
  "channels": 2,
  "frameMs": 20,
  "sink": "tidal_stream",
  "sourceNode": "tidal_stream",
  "outputs": { "ws-pcm": { "enabled": true } }
}
```

- `enabled:false` ⇒ `tidal-stream-sink.service` and `tidal-stream.service`
  are stopped/disabled; nothing is created, no ports bound.
- `enabled:true` ⇒ sink + daemon started. CLI verbs:
  `enable | disable | start | stop | status | url | output on|off <name> | outputs`.
- `status` must print, as parseable lines: sink present?, source linked?,
  listeners, frames/sec, dropped-frame count, `source: up|down`.
- `url` prints the WS URL and, if the box is in a tailnet, the
  `tailscale serve`-style hostname/URL when available (best-effort, never a
  hard failure).

### Outputs (frozen v1 — the fan-out)

One capture, N outputs. `streamd` slices the `pw-record` stream into frames
once and hands the same frame to every **active** output, so outputs are
independent consumers of one source. The source is never dropped to protect an
output; only `ws-pcm`'s own per-connection queue is bounded (drop-oldest).

Config `outputs.<name>.enabled` is the boot state. `ws-pcm` defaults to on and
every other output defaults to off, so pre-refactor behaviour is unchanged.
`bind`/`port`/`token` stay at top level for backward compatibility (they are
`ws-pcm`'s and the status/control server's settings).

Runtime toggling — **no restart, the capture and the other outputs keep
running**:

```
POST /control?token=<token>   {"output":"icecast","action":"on|off","persist":true}
  200 -> {ok:true, output:{…}, status:{…}}     404 -> {ok:false, error, outputs:[names]}
stream-ctl output on|off <name>     # drives the above; falls back to config if the daemon is down
stream-ctl outputs                 # per-output: enabled / active / listeners / dropped
```

`status` (HTTP and CLI) reports each output:
`output: <name> enabled=<bool> active=<bool>`. The HTTP `/status` JSON carries
the same as an `outputs` array of `{name, enabled, active, …}`.

**Output module interface** (how lane 5 adds one): register a plain object with
`streamd`'s `registerOutput()`:

```
name                              stable id, also the config key under outputs
settings                          from outputSettings(name, defaults)
active                            true while started; onFrame only runs when active
async start() / async stop()      idempotent, must not throw
onFrame(msg)                      once per emitted 20 ms frame while active
handleHttp(url, req, res) -> bool  return true when a route was handled
handleUpgrade(url, req, socket) -> bool  return true when the upgrade was handled
status() -> {name, enabled, active, …extra}
```

The registered `ws-pcm` output is the reference implementation (it owns the
WebSocket upgrade, the player page, and the drop-oldest queue).

### Audition job / report protocol (frozen v1)

**CLI surface** — implemented by lane 3 in `tools/audition/audition-ctl`, and the
ONLY audition surface lane 4's plugin tools may call:

```
audition-ctl submit <scene.tidal> [--slot N] [--cps X] [--cycles N] [--with-live]
    -> prints the job <id> on stdout (single line), exit 0
    -> returns immediately; rendering happens on the audition stack
    -> provisions with-live: if the flag is absent, isolated render only
audition-ctl report <id>      -> prints the report JSON object to stdout; exit !=0 if unknown
    -> if the render is still running, print {"ok":false,"state":"running"} and exit 3
audition-ctl jobs [--limit N] -> one line per job: <id> <state> <createdISO> <scene>
audition-ctl status          -> existing verb, unchanged
```

States: `queued | running | done | failed`.

**Job file** `sc/audition/jobs/<id>.json`:

```jsonc
{ "id": "…", "createdMs": 0, "scene": "/abs/path/file.tidal",
  "cps": 0.5, "slot": 2, "renderCycles": 8, "withLive": false }
```

**Report** `sc/audition/reports/<id>.json`:

```jsonc
{ "id": "…", "ok": true, "error": null,
  "state": "done", "startedMs": 0, "finishedMs": 0,
  "cps": 0.5, "slot": 2, "renderCycles": 8, "withLive": false,
  "master": { "peak": 0.0, "rms": 0.0, "headroomDb": 0.0 },
  "bands": { "sub": 0, "bass": 0, "lowmid": 0, "mid": 0, "highmid": 0, "top": 0 },
  "dominantHz": 0,
  "chroma": [ 12 numbers, 0..1 ], "key": "D minor", "dissonance": 0.0,
  "decks": [ { "slot": 2, "letter": "C", "rms": 0.0, "peak": 0.0,
               "headroomDb": 0.0, "dominantHz": 0,
               "bands": { "sub": 0, "bass": 0, "lowmid": 0, "mid": 0, "highmid": 0, "top": 0 },
               "chroma": [ 12 numbers ], "key": "…", "dissonance": 0.0 } ],
  "diffVsLive": { "available": false, "note": "…",
                   "bands": { "sub": 0, "bass": 0, "lowmid": 0, "mid": 0, "highmid": 0, "top": 0 },
                   "dominantHzDelta": 0, "keyClash": false } }
```

Share fields (`bands`, `chroma`) are shares of the total, 0..1. Lane 3 **may add**
fields; it must not rename or remove any above.

**Live comparison (frozen live.json v1).** `diffVsLive.available` is true only
when `sc/audition/reports/live.json` exists AND carries comparable 6-band
readings. The file is written by lane 4's `snapshotLive` from inside the live
sclang; lane 3 reads it opportunistically and must never touch the live stack.

```jsonc
{ "id":"live","source":"live","ok":true,"state":"done",
  "takenMs":0,"takenISO":"…","floorDb":-58,
  "master":{ "bands":{"sub":0,"bass":0,"lowmid":0,"mid":0,"highmid":0,"top":0},
             "dominantHz":0,"rms":0.0,"peak":0.0,"headroomDb":0.0 },
  "decks":[ { "name":"master","rmsDb":0,"dominantHz":0,"low":0,"mid":0,"high":0 } ],
  "raw":"…" }
```

A 3-way `low/mid/high` deck scan is **not** sufficient: it cannot yield the
6-band deltas, and emitting `available:true` with zeroed bands is a false
comparison (this exact bug shipped in lane 4 v1 and was caught in review).
`snapshotLive` must therefore measure the live master with the 6-band meter
(`~spectrumStart` / `~spectrumReport`, already loaded in live via `sc/init.scd`),
settling ~2 s before reading. A 3-way-only snapshot must leave
`available:false`. `keyClash` stays false with a note until live chroma is
measured.

### Lane 3 / lane 4 interfaces

- **lane 3** owns the audition side: `~/livecode/sc/audition/**` (metrics SC
  code, job runner) and `~/pi-tidal/tools/audition/**` (the `audition-ctl`
  verbs above). It may extend the lane-2 files there, and must re-verify the
  lane-2 behaviour it changes (notably the `-D`/stdin question).
- **lane 4** owns the plugin side: `~/pi-tidal/extensions/tidal.ts` and
  `~/pi-tidal/lib/**`. It calls only the CLI verbs above plus `stream-ctl`.
- **Neither** lane edits: the other's paths, `tools/stream/**`, `systemd/**`,
  `sc/init.scd`, `sc/spectrum.scd` (write audition-only meters instead),
  `superdirt_startup.scd`, `BootTidal.hs`, `docs/stream-audition.md`.

**Plugin tool surfaces (frozen):**

```
tidal_stream   { action: "start"|"stop"|"status"|"url"|"enable"|"disable" }
tidal_audition { action: "start"|"stop"|"status"|"submit"|"report"|"jobs",
                 scene?, slot?, cps?, cycles?, withLive?, id? }
```

Parent-approved addition to the frozen list: `tidal_audition { action:
"snapshotLive" }` — lane 4 evaluates `~deckScanStart` / `~orbitScanReport` in the
LIVE sclang and writes `sc/audition/reports/live.json` (the file lane 3 reads
for `diffVsLive`). It must never disturb the live stack.

Both are thin wrappers that shell out to the CLIs and return their output.
`tidal_stream status` must surface the six parseable lines. `tidal_audition
report` must pass the raw JSON through.

**Opt-in stream linking (lane 4).** Linking scsynth's JACK outs to
`tidal_stream` in addition to the physical sink must be **opt-in**: config
`link: false` by default, or `PI_TIDAL_STREAM_LINK=1`. With the gate off, live
routing behaviour must be byte-for-byte unchanged.

### Write-path ownership (avoid two writers in one repo)

- **lane 1**: `tools/stream/**`, `systemd/tidal-stream*.service`, `docs/stream-audition.md`
- **lane 2**: `systemd/tidal-audition.service`, `sc/audition/**` (created it)
- **lane 3**: `sc/audition/**`, `tools/audition/**`
- **lane 4**: `extensions/tidal.ts`, `lib/**`
- **nobody** edits `BootTidal.hs`, `superdirt_startup.scd`, `sc/init.scd`,
  `sc/spectrum.scd`, or any existing `systemd/*` unit.

### Verification each lane must include

Every lane must ship a **runnable** check, not just a claim:

- lane 1: a script/command that (a) proves the sink exists and is not linked
  to a physical output, (b) feeds a known tone and shows the daemon emits
  frames with a monotonically increasing `seq`, (c) shows `status` reporting
  `source: up`, and (d) shows `stop`/`disable` leaves no bound port and no
  sink. Pass requires observed output, not "should work".
- lane 2: a command that boots the audition stack and reports its scsynth
  responds on 57111, SuperDirt on 57121, the `sc/init.scd` graph installed
  (same sentinels as `sc/boot.log`), and that `audition-ctl stop` leaves no
  owned processes. Also: prove it does **not** disturb the live stack.
- lane 3: a command that submits a real scene, waits for `done`, and prints a
  report containing all frozen fields with plausible values; plus a proof that
  a deliberately broken scene yields `ok:false` with an error, not a stuck job.
- lane 4: `node --test tests/*.test.mjs` green with the new wrappers covered by
  pure fixtures (the CLIs are stubbed); plus a live-boot integration check is
  the PARENT's job, not the lane's.

## v0 field notes (observed, contract amended to match)

Lanes 1–2 were verified independently after delivery. Findings that changed
this document:

1. **`pw-record --target <sink>` does NOT capture the sink monitor on this
   box** — WirePlumber links it to the desktop default *source* (the mic). It
   requires `-P '{"stream.capture.sink":true}'`. Verified: the capture stream
   binds `tidal_stream:monitor_FL/FR -> pw-record:input_FL/FR`, and a `vol 0.6`
   tone reads back at amplitude `0.600006`. This is why the probe fetches the
   monitor explicitly.
2. **`ffmpeg -f pulse -device <sink>` silently plays to the default sink** on
   this build (it ignores `-device`), so it cannot feed the tap. Use
   `pw-play --target <sink> <file>`.
3. **`sink-setup.sh create` must not `exec` pw-loopback.** The first version
   did, so running it directly (shell or agent tool call) blocked forever — a
   real 18-minute hang was observed. `create` is now detached (`setsid`, waits
   only for the node to appear) and systemd uses `create-fg`.
4. **`pgrep -f "pw-loopback --name <sink>"` self-matches** any shell command
   line that merely contains the string, so the pidfile recorded the wrong pid.
   All such patterns are now anchored with `^/usr/bin/pw-loopback `.
5. **Audition home override is a compile-time class extension**, not a runtime
   `+ Class {}` (sclang rejects the latter in `executeFile`).
   `Platform.userHomeDir` and `Platform.userAppSupportDir` are separate C++
   primitives, so SuperDirt/mi-UGens/quarks are unaffected — confirmed by a
   0-FAIL audition boot.
6. **Audition graph `boot.log`** is a symlink to the audition-private log rather
   than a real file; live `sc/boot.log` mtime is unchanged across an audition
   boot (verified).
7. **Icecast needs an explicit `-content_type`.** ffmpeg's icecast output does
   not declare one by default, so the mount is served as `audio/mpeg`; every
   listener (ffplay, ffmpeg, VLC) then demuxes the Ogg/Opus stream as MP3 and
   fails with `Header missing` — **while the source looks perfectly healthy**
   (`connected:true`, `bytesOut` climbing, Icecast reporting a live mount). This
   was caught only by decoding a real `icecast2` mount back out; the module now
   passes `-content_type audio/ogg`, and a `vol 0.6` tone reads back at
   amplitude `0.605530`. General rule for this file: *the source pushing bytes is
   not evidence a listener can decode* — verify an output by decoding it, not by
   reading its status.
8. **The audition runner must unmute the slot under test.** The scene mixer
   installs with gains `[1, 0, …]`, so rendering into slot 1+ without raising
   that slot's gain writes into a MUTED channel: the job then reports all-zero
   bands/`key:null` as `ok:true` — a false "this deck is silent" verdict for
   exactly the channels worth auditioning into. Fixed by calling
   `~piSceneAPI[\gains]` per job. It slipped through because the lane-3 selftest
   only ever auditioned into slot 0; the selftest now covers a non-zero slot.
9. **Isolation checks must not compare files the live stack rewrites.**
   `sc/master-meter.log` is rewritten by the live stack's own ceiling meter
   every 2 s while it runs, so an mtime comparison over `sc/*.log` passes only
   when the live stack is idle (measured: the file still grows ~165 B/6 s with
   no audition job running). The check now covers boot.log/engine.log/
   spectrum.log/ctl.log/state.scd and positively asserts the audition wrote its
   own private graph log.
10. **WAN/tailnet listening is exposed to transport stalls, and the server
    cannot see them.** Measured from a remote tailnet host (DIRECT IPv6 path,
    ~140 ms RTT): the stream delivers exactly 50 fps with small jitter (7.6 ms
    EWMA) and ~0 net drift — the transport is fine on average. The arrival tail
    is not: one 60 s window showed p99 149 ms, p99.9 390 ms, **max 450 ms**,
    predicting ~4 underruns/min at ANY target from 60 to 260 ms (a longer target
    only shortens each silence gap, it cannot prevent the stall). A separate
    30 s window was clean (max 120 ms), so path quality varies. You cannot
    buffer past a stall longer than the buffer without paying that latency all
    the time. `stream-ctl status` reports the SERVER's view and cannot tell you
    whether a remote client will glitch — use `tools/stream/probe.mjs` from the
    machine that will actually listen.
    Cautionary note: a hand-rolled simulator of this overstated underruns by
    ~15x because it drained the buffer while repriming (when the client is
    emitting silence and NOT consuming). The corrected model is what the probe
    and this note report.

## Open questions for the operator (not blocking lanes 1–2)

- **Should the fill target react to stalls?** The client's target uses an EWMA
  (alpha 0.05) of arrival deviation, which barely moves on a one-off stall, so
  Ft stays at its 60 ms floor. A peak-hold estimator (react to outliers, decay
  back) was simulated to cut underruns substantially, but roughly doubled the
  mean buffer — i.e. it buys stability with latency, which is the opposite of
  this stream's stated goal. It needs a listening pass, so alpha = 0.05 stands
  for now. See field note 10 for the measurements.

- Opus mode for bandwidth-thrift tailnet/cellular use? (cheap to add behind
  `format`.)
- Icecast/HLS secondary output for third-party players (VLC/phone)?
- Audition scope: isolated render + numeric compare (default) vs mirroring
  the live decks for in-context audition (lane 3 decision).
