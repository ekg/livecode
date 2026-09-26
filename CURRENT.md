# Current jam state — LIVE / RECORDING

**Scene: `100.tidal` (AMP PATTERNS), 104 BPM, D major. — LISTENER-APPROVED**
Recording: `recordings/jam-20260926-1342.wav`, still open at last check (~1300 s).
Committed state: `240aef5`. Marker "100 AMP PATTERNS approved" at 1380.1 s of the take.
Do not auto-restart playback from this file.

## Recall

1. `tidal_sc` → `sc/samples94.scd` (chains 85 → 80 → 76 → 70 aliases, adds `p94brkA-D`).
2. `tidal_sc` → `sc/groove71.scd` (base mixer).
3. `tidal_sc` → `sc/drums90.scd` (drum bus 1.7–2.0).
4. Evaluate `100.tidal` in order.

Live mixer is above the files: master `mGain 1.45`, `mThresh 0.36`, `mGlue 0.62`;
groups drums 2.0 / bass 1.35 / music 1.6 / FX 1.2. Peak measured 0.145.

## What is playing

| Stream | Source | Treatment |
|---|---|---|
| d1 | `p94brkA` (one-bar break, producer_essentials) | `slice 16` on a **16-bar** rotating order; `every 32 (slow 2)`; 8-step gain, never fully off |
| d2/d3/d4 | samba performance, Groove MIDI drummer5 @110 | kick / snare (degraded 55%) / hats, real timing |
| d5 | Tears For Fears "Everybody Wants To Rule The World" bass | syncopated D pedal, fingered bass sample, already in D |
| d6 | `p93arp` (one-bar arp) | granular `chop 8` bursts; `every 13 (# speed 1.25)` screw |
| d7 | — | silent (piano dropped by listener request) |
| d8 | `p93str` string sweep | no chop; `every 21 rev`, `every 7 (# hpf 900)`, slow 0.7/1 swell |
| d9 | TFF D/G chord theme | supermandolin, 16-bar phrase, holes on steps 3/5/8/10/12/16 |
| d10 | `p93perc` ghatam | `struct "t(7,16)"`, `every 11 (hurry 2)` |
| d11/d12 | — | silent |

**The occasional events**: d1's slice-order reshapes land at bars 3, 6, 8, 11, 13 and 15
of its 16-bar cycle (`evod`, `rot 4`, `swap`, `rev`, `evod`, `quart`); d1 slows to half
speed every 32 bars; d6 speeds to 1.25 every 13; d8 reverses every 21; d10 doubles up
every 11. All four now use DIFFERENT prime intervals so they never coincide.

## Key lesson from this session

**Stop swapping loop sources.** Rotating samples per bar (d1 across four breaks)
and `interlace`-ing two loops per bar was described as maddening. The working
approach is **one source per stream, reshaped in place by a long rotating
slice-order**, which yields a 16-bar effective loop from 1 bar of audio. The
audio never changes; only the order does, and mostly it stays identity so the
groove rides.

**Do not put every stream on `every N` with the same N.** d1/d6/d8 were all on
`every 32`, so their variations fired simultaneously and read as a global stutter on
the whole mix. Use distinct prime intervals per stream.

**`striate` was the repeating stutter.** Every `striate n` was removed in 94 and
the "4x repeat on everything" stopped.

**`timeCat` duration is a span, not a fit.** `(n, fast n p)` multiplies density
rather than fitting `p` into `n` cycles. Use `(n, p)` with a one-event-per-cycle
`p`, or a flat mini-notation pattern under `slow n`.

**Mini-notation string literals need `:: Pattern Int`** when the expected type is
ambiguous, or the binding silently fails and the name is out of scope later.

**`~sounds/lpviz` is the loopmaster_2020_vision pack** — the same files. Genuinely
different loop material is in `~/samples/loopmaster_producer_essentials`
(one-bar loops), `~/samples/breaklots` and `~/samples/300 breaks` (full tracks,
19–50 s — do NOT `loopAt 8` these, it smears them into noise).

## Open issues

- **Slow voice leak:** synth count drifted from 130 to ~180–230 across the
  session and does not fully return. Not yet cleaned; `freeSynths` would fix it
  but would interrupt a sound the listener has approved.
- **Piano is off.** `dubchord` and the `superpiano` air arpeggio are parked in
  `92.tidal` / `93.tidal`.
- **SCLOrk synths are loaded but barely used.** `FMRhodes1` and `sosBell` are
  registered via `~dirt.soundLibrary.addSynth` and available by name;
  ~109 more definitions sit in `~/synth-libraries/SCLOrkSynths/SynthDefs/`.
  MI UGens installed but never integrated.
- **`master_inert` Tidal params still do not reach the master**; use `~masterSet`.
- The loaded Pi extension still has the stale `stopOwnedProcessTree` helper bug;
  the disk fix is committed but not activated.

## Version index (all committed and pushed)

| Scene | Character |
|---|---|
| 73–74 | approved LPViz loop playground; "Slick Muffin" pluck checkpoint |
| 75–78 | eight-bar chop breakdown, walking bass, ringing melody, approved **CHOICE** |
| 80 | SKYWARD: C-minor → D-major lift, four-loop chain |
| 81–83 | 3/5/7-bar prime interplay; broken piano |
| 84 | coprime swells, turnaround variation, filter opening, cadence throw |
| 85–86 | 16-bar drum arc, 64-bar gates; seven-bar walking bass |
| 87 | total transition: Air arpeggio + human ijexa, LPViz loops dissolve |
| 88–90 | breakdown; build back; approved FULL BUILD (samba + rhumba) |
| 91–92 | thinned drums; sewn/striated LPViz weave |
| 93 | every loop swapped to breaklots/300breaks/producer_essentials |
| 94 | striate removed; real one-bar breakbeats |
| 95 | approved REBUILD: TFF 80s bass + D/G chord theme |
| 96–97 | stable single-source loops; three-and-one |
| 98 | long effective loop: one source, 16-bar rotating slice-order |
| 99 | per-stream prime-interval treatments (no more coincident variation) |
| 100 | **amp patterns for space — current, approved** |

Enjoy the ride, don't flatten it.
