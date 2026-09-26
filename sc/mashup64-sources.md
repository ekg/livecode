# 64 — CHANNEL SURF / AFTER THE MALL

98 BPM. Repeating 64-bar form: 24 bars neon-pop, 8 bars dub crossfade,
24 bars dark halftime, 8 bars return. Sound is synthesized; no commercial master
audio is used. Sources are local third-party transcriptions, not asserted to be
public-domain material. Source metadata keys/tempos can be wrong; pitches were
read from the converted notes rather than trusting the generic CMajor headers.

## Local source excerpts / transformations

All paths below are relative to `~/tunepile/tabs-tidal/`.

- **Michael Jackson — Billie Jean (1982)**:
  `Jackson_Michael_-_Billie_Jean_2_.gp4-87308cb7.tidal`.
  The transcribed guitar's F#–C#–E–F#–E–C#–B–C# shape becomes a short eighth-note
  synth-bass ostinato, moved down in register.
- **Tears for Fears — Everybody Wants to Rule the World (1985)**:
  `Tears_For_Fears_-_Everybody_Wants_To_Rule_The_World.gp4-ad059e35.tidal`.
  F#–A–F#–B–F#–A–F#–A theme fragment on vibes, with occasional reversal.
- **Daft Punk — Digital Love (2001)**:
  `Daft_Punk_-_Digital_Love.gp4-cb2f3cde.tidal`.
  First 32 keyboard grid cells revoiced as PWM, with low-pass motion and
  five-sixteenth-cycle delay. Harmony surrounding these excerpts is newly voiced.
- **Portishead — Glory Box (1994)**:
  `Portishead_-_Glory_Box.gp3-a97d3f35.tidal`.
  Eb–Db–C–B bass descent transposed down three semitones to C–Bb–A–Ab;
  rhythmic compression and original upper chord extensions.
- **Massive Attack — Teardrop (1998)**:
  `Massive_Attack_-_Teardrop.gp4-7f78abbd.tidal`.
  A–A–E–A–D–A–D–E excerpt transposed up three semitones, condensed to two bars,
  played on physical-model mandolin.
- **Britney Spears — Everytime (2004)**:
  `Spears_Britney_-_Everytime.gp4-dd531691.tidal`.
  Opening C–E–G–E–C–G–E–G arpeggio reshaped to minor (Eb), shortened,
  reversed every fourth cycle and revoiced as FM.

Modern club/glitch percussion and production are original additions, not claims
of sourced Weeknd/Dua Lipa/Billie Eilish excerpts: those searches returned no
relevant transcriptions in this corpus.

## Playback / validation

Load `sc/mashup64.scd` through the running plugin-owned sclang, then evaluate
`64.tidal` in file order. Statements and streams are single-line chunks.

The installed `Sound.Tidal.Boot` does not export `arrange`. This file now uses
only built-in `slow`, `timeCat` and `fast` for its form; each stream carries its
own schedule. Offline validation imported the installed Boot module and project
parameter declarations without starting a Tidal stream/audio process:

- all 12 streams type-checked and rendered over 64 bars;
- event counts: 200, 78, 575, 184, 288, 288, 416, 546, 56, 0, 0, 0;
- principal lead has events in all eight 8-bar windows;
- the one-line chunk linter passes.
