# Replayable arrangements

These scenes perform transitions from **local bar zero**, independently of the
shared Tidal clock. They do not overwrite their numbered source tracks.

## Window Seat: breakdown and drum breaks

```
/tidal scene load A arrangements/159-breakdown.tidal
```

At 74 BPM (one cycle = one 4/4 bar):

- **Bars 0–3:** filtered, quieter Rhodes and sparse hats; kick/snare/bass out.
- **Bars 4–7:** restrained bass and the saved hat pattern build beneath the keys.
- **Bars 8–9:** alternate chopped kick/snare patterns, ghost hits, a final roll,
  and occasional short snare echoes. Melody sits out for the drum break.
- **Bar 10 onward:** the full saved `159.tidal` groove returns automatically.

Use `restart A` to perform it again. Editing preserves phase, so an edit after
bar 10 does not replay the breakdown. The arrangement runs on the existing
scene system; no master modulation, extra orbits, timers or unowned routines.

## Rebuild and offline validation

```
node tools/build_window_seat_breakdown.mjs
```

This rebuilds from `159.tidal`, parses the scene and compiles/queries the installed
Tidal library with `runghc`. It checks that bars 10–17 play exactly the saved groove's note onsets and
parameter values (ignoring irrelevant query clipping and event ordering). It never boots
or plays audio. SC playback still requires the project's normal DSP setup.

The helper finds pi-tidal at `~/pi-tidal`; set `PI_TIDAL_DIR` if installed elsewhere.
It deliberately fails if the source scene's modulation changes unexpectedly,
rather than silently generating a partial or incorrect arrangement.
