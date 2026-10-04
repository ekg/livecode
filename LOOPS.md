# Loop aliases — what the curated `pNN*` sample names actually point at

The SuperDirt library has ~780 folders. The loop material we actually use is
**aliased** to short names (`p70drumA`, `p93drumB`, …) because the real files live
in `~/samples/` packs whose names are long/awkward. This is the map, recovered
from the buffers' paths at runtime:

| name | file it points at |
|---|---|
| `p70drumA` | `loopmaster_2020_vision/2020_DD_96_DrumLp2.wav` |
| `p70drumB` | `loopmaster_2020_vision/…` |
| `p70perc` | `loopmaster_2020_vision/…` |
| `p85drumA` | `loopmaster_2020_vision/2020_RL_123_DrumLp1.wav` |
| `p93drumA` | **`breaklots/01 - Track01.wav`** |
| `p93drumB` | **`300 breaks/12 - Track12.wav`** |
| `p93perc` | `loopmaster_producer_essentials/GHATAM 02.wav` |
| `p93arp`, `p93arp2` | `loopmaster_producer_essentials/arp1.wav`, `arp2.wav` |
| `p93str` | `…/Arp Odyssey String Sweep 2 A.wav` |
| `p94brkA` | `…/Funky 6 A 108.5bpm.wav` |
| `p94brkB` | `…/Funky 3 A 115bpm.wav` |
| `p94brkC` | `…/Phat 11 A 111bpm.wav` |
| `p94brkD` | `…/2step 5 130bpm.wav` |

Underlying packs on disk: `~/samples/300 breaks`, `~/samples/breaklots`,
`~/samples/loopmaster_2020_vision`, `~/samples/loopmaster_producer_essentials`.

## The two big loop packs are NOT drum-only

`lpmr` (1117 files) and `lpviz` (598 files) are the whole `loopmaster_*` packs
flattened: drum loops, basses, brass, guitar, **vocals** and FX all in one
namespace, indexed only by `n`:

```
lpviz  50: 2020_DD_126_DrumLp1.wav    lpviz 360: 2020_PH_Perc6.wav     ← usable
lpviz 280: 2020_EP_Vox2.wav            lpviz 120: 2020_DD_FX40.wav     ← the "mousey"
```

So `s "lpviz" # n (choose [...])` is a lottery — some draws are vocal/FX loops,
and at `slice 13` with dense orders they read as squeaky chirps. If you want
guaranteed drums, use the `pNNdrum*` / `pNNbrk*` aliases instead.

There are also true drum-only folders: `breaks125/152/157/165`, `amencutup` (32),
`jungle` (13 one-shots: closedhh/crash/kick/snare/perc…), `drumtraks` (13: DT
Claps/Kick/Snare/Tom…), `drum` (6), `ifdrums` (ignorebd/ignorehh/ignoresd).

## Rate: `speed` vs `loopAt` vs `slow`

| control | effect | watch out |
|---|---|---|
| `speed 0.8` | playback rate −20%, pitch follows | keeps slice→cycle mapping |
| `loopAt 2` | fits the whole loop over 2 cycles ⇒ speed halved | slices then span 2 cycles, diluting the metre |
| `loopAt 4` | quarter speed, two octaves down | "insanely slowed" — use deliberately |
| `slow 2` | stretches event timing, no pitch change | does not slow playback |

And a reminder that bites: for **sample** melodies, `note` *is* playback speed, so
low notes drag the sample down (`gs3` on a marimba = molasses) and high ones
squeak (`|+ note 12` = 2× speed).
