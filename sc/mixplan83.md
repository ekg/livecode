# 83 mix + modulation plan

Live scene: `83.tidal`, 104 BPM, D major. Mixer: `sc/groove71.scd`.
This is a discussion document, not an instruction to apply everything at once.

## Current inventory (11 active streams)

| Stream | Role | Material | Period |
|---|---|---|---|
| d1 | foundation | chopped 16 `p70drumB` | 1 bar |
| d2 | groove | performed snare/soft | 8 bars |
| d3 | groove | performed hats | 8 bars |
| d4 | foundation | backbeat claps | 1 bar |
| d5 | foundation | walking fingered bass | 4 bars |
| d6 | foreground | chopped LPViz melodic loop | 2 bars |
| d7 | foreground | broken piano (chords/fragments/rolls) | 11 bars |
| d8 | foreground | cpluck answer | 8 bars |
| d9 | counterpoint | Rhodes | 3 bars |
| d10 | groove | `p70perc`, 5/4 mask | 1 bar |
| d11 | counterpoint | body percussion + coffee | 5 bars |
| d12 | counterpoint | supermandolin | 7 bars |

Prime interplay already present: **3, 5, 7, 11**. Combined recurrence is long
enough that the texture effectively never resets.

## The actual problem is hierarchy, not content

Eleven streams of similar weight compete. The fix order is:

1. **Foundation** — d1, d5, d4. Should always be legible and never ducked.
2. **Groove** — d2, d3, d10. Provide motion; can drop out for sections.
3. **Foreground** — d7 piano, d6 loop, d8 answer. Take turns; should not all
   peak simultaneously.
4. **Counterpoint** — d9, d11, d12. Quiet, spectrally separated, and *gated by
   long fades* so they never all overlap.

Current spectral placement is already reasonable: mandolin high/right with a
9.5 kHz ceiling, Rhodes mid/left at 11 kHz, body percussion low-mid and paired
pans, piano at 12 kHz. The weakness is temporal overlap, not register.

## Modulation axes

### A. Coprime long fades (highest value, lowest risk)

`envL` is an 8-cycle ramp: 0 → 1 across its span, then held at 1. Scaled by
`slow N`, the ramp length becomes `8 × N` cycles:

| Layer | Expression | Fade length |
|---|---|---|
| d9 Rhodes | `slow 3 envL` | 24 bars |
| d11 body perc | `slow 5 envL` | 40 bars |
| d12 mandolin | `slow 7 envL` | 56 bars |
| d7 piano | `slow 11 envL` | 88 bars |
| d8 answer | `slow 4 envL` | 32 bars |

Because 3/5/7/11 are coprime, entrances and exits land in different places for
a very long time. This is the direct answer to "layering different primes".
`envR` (descending) or `envL * envR` (arch) can shape sections instead of a
one-shot build.

### B. Beat variation without losing the pocket

d1's `bite 8 "0 1 2 [3 1] 4 7 6 ~"` is currently identical every bar. Options:

- change the order on a slow cycle, e.g. alternate two entire orders every 8 bars;
- `sometimesBy 0.25 (chop 16)` for occasional double-time bars;
- `degradeBy` a single slice index so one hit drops out and returns;
- `every 16 (rev)` for a turnaround bar.

Keep d4 and d5 unmodulated so the groove stays grounded while d1 moves.

### C. Per-layer filter movement

Slow LPF opening on one loop across a section — not a master filter. A master
cutoff change muffles everything, which the listener has already rejected.
Better: open d6 or d8's own filter across 16–32 bars so the layer brightens
into a section.

### D. Delay throws at phrase boundaries

d7 currently throws delay every fourth bar via `"<0.1 0.1 0.1 0.25>"`. Since
the piano phrase is 11 bars, aligning the throw to the phrase end
(`delaySend "<0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.34>"`) would land the
echo on the real cadence instead of at arbitrary points.

### E. Section arrangement

A 64- or 128-bar `timeCat` on the *gain* of each counterpoint layer produces a
composed arrangement: intro, additions, breakdown, return. This is the same
technique already used in `80.tidal`'s four-loop chain, applied to level
instead of source.

## Suggested order of work

1. Apply coprime fades (A) to d9, d11, d12 — immediate reduction in clutter.
2. Move d7's delay throw to the phrase end (D).
3. Add one beat variation to d1 (B) so the foundation breathes.
4. Only then consider section-level arrangement (E).

Each change should be auditioned and committed separately so any axis can be
reverted independently. `78.tidal` (CHOICE) and `82.tidal` remain intact
return points.
