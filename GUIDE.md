# Tidal Patterns and Techniques Guide

## Basic Rhythm Structures

### Using `struct` for Rhythmic Patterns
Common patterns use Euclidean rhythms with `struct "t(n,k,o)"` where:
- n = number of hits
- k = total steps
- o = offset

```haskell
-- Basic examples
d1 $ struct "t(3,8)" $ s "bd"  -- 3 hits evenly spaced over 8 steps
d1 $ struct "t(5,8,2)" $ s "hh" -- 5 hits over 8 steps, offset by 2

-- Complex variations
d1 $ struct "t(<3 5 7>,8,<0 2>)" $ s "drum" -- varying number of hits
d1 $ struct "t(11,16,14)" $ s "hh" -- dense hi-hat pattern
```

### Basic Rhythm Building
```haskell
-- Four-on-the-floor
d1 $ s "bd*4"

-- Offbeat patterns
d1 $ s "~ cp ~ cp"

-- Combined patterns
d1 $ stack [
  s "bd*4",
  s "~ cp ~ cp",
  s "hh(3,8)"
]
```

## Pattern Manipulation

### Speed and Time Manipulation
```haskell
-- Using hurry
d1 $ every 4 (hurry 2) $ s "bd cp bd cp"

-- Using fast/slow
d1 $ fast 2 $ s "bd cp"
d1 $ slow 2 $ s "bd cp"

-- Using loopAt
d1 $ loopAt 2 $ chop 8 $ s "break"
```

### Tempo Control
```haskell
-- Set tempo in BPM
setcps (120/60/4)  -- 120 BPM
setcps (85/60/4)   -- 85 BPM

-- Variable tempo
setcps ((range 100 150 (slow 4 saw))/60/4)  -- Sweeping tempo
```

### Timing and Swing
```haskell
-- Basic swing using nudge
d1 $ s "bd*4" # nudge (fast 8 "0 0.02")

-- Complex swing pattern
let swing = always (# nudge (fast 7 "-0.005 0.005 0.002 -0.003"))
d1 $ swing $ s "bd cp bd cp"

-- Multiple swing rates
d1 $ stack [
  s "bd*4" # nudge (fast 8 "0 0.02"),
  s "hh*8" # nudge (fast 16 "0 0.01")
]
```

### Pattern Transformation
```haskell
-- Reverse patterns
d1 $ every 4 (rev) $ s "bd cp hh sd"

-- Palindrome
d1 $ palindrome $ s "bd cp hh sd"

-- Jux (juxtapose)
d1 $ jux (rev) $ s "bd cp hh sd"

-- Rolled (arpeggiate chords)
d1 $ rolled $ note "c'maj"

-- Move (offset patterns)
d1 $ move $ s "bd cp hh sd"
```

### Binary Patterns
```haskell
-- Using binary numbers for rhythms
d1 $ struct (binary 170) $ s "bd" -- 10101010
d1 $ struct (binaryN 16 43690) $ s "bd" -- 1010101010101010

-- Inverting binary patterns
d1 $ struct (inv (binary 170)) $ s "bd"
```

## Effects and Processing

### Basic Effects
```haskell
-- Room reverb
d1 $ s "bd*4" # room 0.8 # size 0.9

-- Delay
d1 $ s "cp" # delay 0.8 # delaytime (1/3) # delayfeedback 0.8

-- Distortion and Crush
d1 $ s "bd" # distort 0.4 # crush 8
```

### Filter Manipulation
```haskell
-- Low-pass filter
d1 $ s "bd*4" # lpf 1000

-- High-pass filter
d1 $ s "hh*8" # hpf 3000

-- Filter modulation
d1 $ s "bd*4" # lpf (range 400 4000 $ slow 4 sine)

-- DJ-style filter
d1 $ s "bd*4" # djf 0.7 -- 0=lpf, 1=hpf

-- Filter bus modulation
d1 $ s "bd*4" # djfbus 1 (range 0 1 $ slow 4 sine)
```

### Clouds (Granular Effects)
```haskell
-- Basic clouds
d1 $ s "bd*4" # clouds 0.5 0.5 0.3 0.4

-- Clouds blend parameters
d1 $ s "bd*4" # cloudsblend 0.9 0.7 0.4 0.5

-- Clouds freeze
d1 $ s "bd*4" # cloudsfreeze 1
```

### Rings (Resonator)
```haskell
-- Basic rings
d1 $ s "bd*4" # rings 0.5 0.7 0.4 0.6 0.3

-- Rings parameters
d1 $ s "bd*4" # ringspos 0.5 # ringsstruc 0.7 # ringsbright 0.4 # ringsdamp 0.6 # ringsmodel 0.3
```

## Melodic Patterns

### Using Notes and Scales
```haskell
-- Basic note pattern
d1 $ note "0 3 7 10" # s "superpiano"

-- Using scales
d1 $ note (scale "minor" "0 2 4 5") # s "superpiano"

-- Chord progressions
d1 $ note "<'min7 'maj7 'dom7>" # s "superpiano"

-- Note taking from list
d1 $ note (noteTake "melody" [0,2,4,7]) # s "superpiano"

-- Octave shifting
d1 $ note "0 3 7" # octave 5 # s "superpiano"
```

### MIDI Control
```haskell
-- Basic MIDI note
d1 $ note "0 3 7" # s "midi0"

-- MIDI control changes
d1 $ ccv (range 0 127 $ slow 4 sine) # ccn 1 # s "midi0"

-- MIDI channel
d1 $ note "0 3 7" # s "midi0" # midichan 2
```

### Arpeggiation
```haskell
-- Basic arpeggio
d1 $ arp "up" $ note "c'maj" # s "superpiano"

-- Complex arpeggio
d1 $ arp "<up down diverge>" $ note "<c'maj f'min>" # s "superpiano"
```

## Layering and Composition

### Pattern Variables and Let Bindings
```haskell
-- Define pattern variables
do
    let swing = nudge (fast 8 "0 0.02")
    let bass = note "0 3 5 7" # s "bass"
    let drums = stack [s "bd*4", s "~ cp ~ cp"]
    d1 $ swing $ stack [drums, bass]

-- Complex pattern composition
do
    let melody = note "c a f e"
    let chords = note "<c'maj f'maj>"
    let rhythm = struct "t(3,8)"
    d1 $ stack [melody # s "lead", chords # s "pad", rhythm # s "drums"]
```

### Using Stack
IMPORTANT: Never include empty lines (double newlines) in do blocks or any code that needs to be executed as one unit. The operator's interface treats empty lines as separators between different code chunks.

```haskell
-- Basic stacking (note: no empty lines between code lines)
d1 $ stack [
  s "bd*4",
  s "~ cp ~ cp",
  s "hh(3,8)",
  note "0 3 5 7" # s "bass"
]

-- Advanced stacking with effects (note: no empty lines)
d1 $ stack [
  s "bd*4" # lpf 800,
  s "~ cp ~ cp" # room 0.5,
  s "hh(3,8)" # pan sine,
  note "0 3 5 7" # s "bass" # shape 0.3
]

-- Conditional stacking
d1 $ stack [
  s "bd*4",
  every 4 (const silence) $ s "~ cp ~ cp",
  whenmod 8 6 (const silence) $ s "hh*8",
  every 2 (# gain 0) $ note "0 3 5 7" # s "bass"
]
```

### Pattern Combination
```haskell
d1 $ every 4 (fast 2) $ stack [
  s "bd(3,8)",
  s "cp(3,8,2)",
  note "0 3 5 7" # s "bass"
] # room 0.3

d2 $ every 2 (rev) $ s "hh*8" # gain 0.8
```

## Advanced Techniques

### Stutter Effects
```haskell
-- Basic stut
d1 $ stut 4 0.5 0.125 $ s "bd cp"

-- Complex stut
d1 $ every 4 (stut 3 0.7 (1/8)) $ s "bd cp sd hh"

-- Multiple stut layers
d1 $ stut 3 0.7 (1/8) 
   $ stut 2 0.5 (1/16)
   $ s "bd cp"

-- Conditional stut
d1 $ every 8 (stut 4 0.6 (3/16)) 
   $ every 4 (stut 2 0.5 (1/8))
   $ s "bd cp"
```

### Conditional Patterns
```haskell
-- Using every
d1 $ every 3 (fast 2) $ every 4 (# crush 4) $ s "bd cp"

-- Using whenmod
d1 $ whenmod 8 6 (fast 2) $ s "bd cp"
```

### Random and Chaotic Elements
```haskell
-- Using rand
d1 $ s "bd*8" # pan rand

-- Using irand
d1 $ s "drum*8" # n (irand 8)
```

## Mixing Techniques

### Volume Control
```haskell
-- Basic gain
d1 $ s "bd cp" # gain 0.8

-- Dynamic gain
d1 $ s "bd cp" # gain (range 0.7 0.9 $ slow 4 sine)

-- Orbit routing for effects
d1 $ s "bd cp" # orbit 1
d2 $ s "hh sd" # orbit 2

-- Complex effect routing
d1 $ stack [
  s "bd*4" # orbit 1 # room 0.8,
  s "cp(3,8)" # orbit 2 # delay 0.5,
  s "hh*8" # orbit 3 # lpf 2000
] 

-- Effect buses
d1 $ s "bd cp" 
   # lpfbus 1 (range 200 2000 sine)
   # delaybus 2 (range 0.1 0.5 saw)
```

### Spatial Effects
```haskell
-- Panning
d1 $ s "bd cp" # pan (range 0.3 0.7 $ slow 4 sine)

-- Room size variation
d1 $ s "bd cp" # room (range 0.1 0.8 $ slow 8 sine)
```

### Performance Transitions
```haskell
-- Crossfade
xfadeIn 1 8 $ s "bd cp"

-- Pattern switching
d1 $ ur 16 "pat1 pat2 pat3 pat4" [
  ("pat1", s "bd cp"),
  ("pat2", s "hh sd"),
  ("pat3", note "0 3 5 7" # s "bass"),
  ("pat4", s "arpy*8")
] []
```

## Sample Manipulation

### Working with Samples
```haskell
-- Basic sample playback
d1 $ s "bd cp hh" 

-- Sample selection with n
d1 $ s "drum*4" # n (run 8)

-- Sample bank switching
d1 $ n "0 1 2 3" # s "[drum, jazz, world]"

-- Sample attributes
d1 $ s "break" 
   # begin 0.2    -- Start point
   # end 0.8      -- End point
   # speed 0.5    -- Playback speed
   # unit "c"     -- Cycle units
   # loop 2       -- Loop count
```

### Chopping Samples
```haskell
-- Divide a sample into 8 parts and play them in reverse order
d1 $ chop 8 $ s "break"

-- Divide a sample into 16 parts, reverse the order, and apply a stutter effect
d1 $ stut 4 0.5 0.125 $ chop 16 $ s "break"

-- Divide a sample into 32 parts, select parts 1, 3, 5, and 7, and play them in reverse order
d1 $ slice 32 "1 3 5 7" $ s "break"

-- Complex slicing patterns
d1 $ slice 16 "0 3 8 2 11 4" $ s "break"

-- Time-stretched slicing with loopAt
d1 $ loopAt 4 $ chop 16 $ s "break"

-- Combining slice techniques
d1 $ every 4 (slice 8 "7 6 5 4 3 2 1 0")
   $ loopAt 2 
   $ chop 16 
   $ s "break"
```

-- Divide a sample into 16 parts, select parts 2, 4, 6, and 8, and apply a stutter effect
d1 $ stut 4 0.5 0.125 $ slice 16 "2 4 6 8" $ s "break"
```

### Stutter Effects
```haskell
-- Repeat a sample 4 times with a stutter effect
d1 $ stut 4 0.5 0.125 $ s "break"

-- Repeat a sample 8 times with a stutter effect and apply a filter
d1 $ stutter 8 (|* lpf 1000) $ s "break"
```

### Looping Samples
```haskell
-- Loop a sample at 2 seconds
d1 $ loopAt 2 $ s "break"

-- Loop a sample at 4 seconds and apply a filter
d1 $ loopAt 4 $ s "break" # lpf 1000
```

## Reordering Samples

### Reversing Samples
```haskell
-- Reverse the order of a sample
d1 $ rev $ s "break"

-- Play a sample in reverse order, then forward
d1 $ palindrome $ s "break"

-- Juxtapose two samples
d1 $ jux (rev) $ s "break"
```

## Integrated Examples

### Layered Electronic Track

```haskell
-- Set global tempo
setcps 0.5

-- Define some variables for reuse
let bassline = note (scale "minor" "0 3 5 7")
    melody = note (scale "minor" (
        "4 0 0 0 3 0 0 0 4 0 4 5" 
        + (floor <$> range 0 7 (slow 4 sine))
    ))
    gate = "<t(11,16,<0 2>)>"

-- Main pattern combining multiple techniques
do
    d1 $ stack [
        struct (binary 170) $ s "bd" # gain 1.2,
        struct "t(5,8)" $ s "cp" # room 0.3,
        struct "t(11,16)" $ s "hh" # gain 0.8 # pan sine
    ]
    d2 $ every 4 (fast 2) $ bassline 
        # s "supersaw" 
        # lpf (range 400 3000 $ slow 8 sine) 
        # resonance 0.3 
        # gain 0.9
    d3 $ melody 
        # s "superchip" 
        # room 0.6 
        # size 0.8 
        # delay 0.4 
        # delaytime (1/3) 
        # delayfeedback 0.3
    d4 $ stut 4 0.5 0.125 
        $ struct gate 
        $ s "ambient:2" 
        # gain 0.7 
        # clouds 0.4 0.4 0.1 0.7 
        # cloudsblend 0.5 0.7 0.3 0.7
```

### Orchestral-Electronic Fusion

```haskell
-- Complex orchestral pattern with electronic elements
do
    d1 $ stack [slow 32 $ note (scale "minor" "0 2 -3 1 8 0 0 4"), slow 16 $ note (scale "minor" "0 2 7 1 4 0 0 4"), slow 8 $ note (scale "minor" "0 2 7 1 8 0 0 4")] # s "cbow:0" # room 0.8 # size 0.9 # gain 0.9
    setB "dynb" (binary "<170 148 191 168>")
    setI "dyni" (run 4)
    setF "dynf" (rand)
    d2 $ struct "^dynb" $ s "[bd*4, cp(3,8)]" # n "^dyni" # pan "^dynf" # verb 0.4 0.6 0.3 0.2
    d3 $ every 4 (fast 2) $ arp "up down converge" $ note "<c'min7 f'maj7 g'dom7>" # s "superpiano" # room 0.6 # lpf (range 800 4000 $ slow 8 sine)
```

### Rhythmic Pattern Integration

```haskell
-- Complex rhythmic integration with multiple techniques
do
    -- Define pattern fragments
    let pats = [
            ("drums", stack [
                s "bd*4",
                s "~ cp ~ cp",
                s "hh(7,16)"
            ]),
            ("bass", note "c3 g3 a3 e3" # s "bass"),
            ("lead", note (scale "minor" "0 3 5 7") # s "lead")
        ]
        fx = [
            ("reverb", (# room 0.8 # size 0.9)),
            ("distort", (# distort 0.4 # gain 0.8)),
            ("filter", (# lpf 1000 # resonance 0.3))
        ]

    -- Main rhythmic pattern using ur for pattern mixing
    d1 $ ur 16 "drums drums:reverb bass:filter lead:distort" pats fx

    -- Additional polyrhythmic layer
    d2 $ stack [
        struct "t(3,8)" $ s "drum:0" # gain 0.9,
        struct "t(5,8)" $ s "drum:1" # pan sine,
        struct "t(7,16)" $ s "drum:2" # room 0.4
    ] # shape 0.3

    -- Granular texture layer
    d3 $ stutWith 8 (1/16) (|* crush 1.1)
        $ s "ambient:3*4"
        # gain 0.7
        # clouds 0.3 0.5 0.2 0.6
```

### Performance-Oriented Pattern

```haskell
-- Pattern designed for live manipulation
do
  setcps (117/60/4)
  let l = s "lpviz"
  d1 $ stack [every 4 (rev) $ loopAt 2 $ chop 16 $ l # n 310
             , every 8 (stut 3 0.7 (3/8)) $ compress (1/4, 3/4)
               $ every 16 (* note "0 7 -12 -5")
               -- $ every 4 (hurry 2)
               $ note (slow 2 "<0 3 0 7>") # l # n 281
             , -- every 4 (compress (3/4, 4/4)) $ compress (0/4, 1/4) $
               slow 4 $ every 3 (rev)
               $ slice 32 "16 19 0 7" $ loopAt 4 $ chop 8 $ l
               -- # n "<493 491 492 433>"
               # n "<491 492>"
               # legato 1 # speed 0.98 # gain 0.9 # crush "<4 4 5 7 9>"
             , s "808bd*4" # n 3
             , every 8 (# gain 0) $ fast 2 $ s "~ realclaps" # n "[3, 4, 7]" # room 0.1 # sz 0.8
             , struct "t(3,7)"
               $ s "808mt(<12 12 13>,14,11)"
               # speed (cat ["1 0.5 0.7 0.66"
                            , "1 1 1 1"
                            , "0.5 0.6 0.66 0.7"
                            , "1 1 1 1"])
             ]

### Performance-Oriented Pattern

```haskell
-- Pattern designed for live manipulation
do
    d1 $ stack [
        every 4 (fast 2) $ s "bd*4" # gain 1.1,
        every 3 (rev) $ s "~ cp ~ cp" # room 0.4,
        sometimesBy 0.3 (# speed 2) $ s "hh*8" # gain 0.8
    ]
    d2 $ note (scale "minor" "<[0 3 5 7] [2 5 7 9]>") 
        # s "supersquare" 
        # lpf (range 400 4000 $ slow 8 sine) 
        # resonance 0.3 
        # room 0.6 
        # size 0.8
    let pattern1 = stack [
        s "bd*4",
        note "0 3 5 7" # s "bass"
    ]
    let pattern2 = stack [
        s "cp(3,8)",
        note "2 5 7 9" # s "lead"
    ]
    xfade 3 $ every 4 (fast 2) pattern1
    d4 $ s "ambient:4" 
        # gain 0.7 
        # room (range 0.2 0.8 $ slow 16 sine) 
        # delay 0.5 
        # delaytime (1/3) 
        # delayfeedback 0.4
```

This comprehensive guide covers a wide range of techniques and patterns in TidalCycles, including:

* Basic rhythm structures using `struct` and Euclidean rhythms
* Pattern manipulation with `hurry`, `fast`, `slow`, and `loopAt`
* Effects processing with reverb, delay, distortion, and filtering
* Melodic patterns using notes and scales
* Layering and combining patterns with `stack` and `ur`
* Advanced techniques like stutter effects, conditional patterns, and random elements
* Mixing techniques for volume control, spatial effects, and performance transitions
* Sample manipulation with chopping, slicing, stuttering, and looping
* Reordering samples with reversing, palindromes, and juxtaposition
* Integrated examples of layered electronic tracks, orchestral-electronic fusion, rhythmic pattern integration, and performance-oriented patterns

## Commonly Used Samples

### Drum/Percussion Samples
1. 808 Family:
   - 808bd (especially n "3", "4") - Bass drums
   - 808oh - Open hats
   - 808mt - Mid toms
   - 808hc - High conga
   - 808lc - Low conga

2. CPU/CPU2:
   - cpu2 (especially n "0", "2", "3", "8") - Electronic drum hits
   - cpu - Digital percussion

3. Claps/Snares:
   - realclaps (n "2", "3", "7") - Natural clap sounds
   - cp - Classic clap sounds
   - sd - Snare drums

4. Breaks:
   - breaks125 - Classic breakbeats
   - breaks152 - More breakbeats
   - breaks157 - Additional breaks
   - breaks165 - Extended breaks

### Melodic/Tonal Samples
1. Mars Synths:
   - mars_synths_S612_Rhodes - Electric piano sounds
   - mars_synths_KawaiiDreams_Air - Atmospheric pads
   - mars_synths_360_Bass - Bass sounds
   - mars_synths_SK1_Organ - Organ tones
   - mars_synths_DrSample_Strings - String sounds

2. Bass Sounds:
   - flbass (especially n "2", "3", "8") - Bass instruments
   - jvbass - Classic bass sounds
   - bass3 - Additional bass tones

3. Keys/Pads:
   - jrhodes - Rhodes electric piano
   - superpiano - Piano sounds
   - supervibe - Vibraphone sounds
   - gtr - Guitar tones

4. Textural:
   - lpviz (many numbers including "388", "389", "832", "735", "736") - Various textures
   - lpmr - Additional textural elements
   - reggae (various numbers including "30", "38", "39", "44", "93", "109", "133", "134") - Reggae samples

### Common Effects Applications
- Speed adjustments (0.5-2.0 range common)
- Room/Size for space (0.3-0.9 typical)
- LPF/HPF filtering
- Distortion/crush for texture
- Delay/stutter for rhythm
- Cut for sample isolation

By mastering these samples and their manipulation, you can create complex and engaging live coding performances with TidalCycles.

## Pattern Reset and Structure

### Resetting All Instruments
Always structure your patterns with a `do` block that includes `hush` at the start and sets the tempo. This ensures a clean slate:

```haskell
do
  hush
  setcps (126/60/4)
  -- Your pattern code here
```

### Example Pattern Structures

1. Basic House Pattern:
```haskell
do
  hush
  setcps (126/60/4)
  -- Core rhythm
  d1 $ stack [
    s "bd(3,8)" # gain 1.2,
    s "~ cp ~ cp" # room 0.3,
    s "hh*8" # gain 0.8 # pan sine ]
  -- Bass line
  d2 $ note "c1(3,8,1)" # s "bass3"
    # lpf 800 # resonance 0.2
  -- Hi-hats
  d3 $ s "808oh(5,8)" # gain 0.7
```

2. Ambient Pattern:
```haskell
do
  hush
  setcps (85/60/4)
  -- Atmospheric pad
  d1 $ slow 4 $ note "<c4'maj7 a3'min7>"
    # s "supersaw" # room 0.8
  -- Gentle percussion
  d2 $ s "jazz(3,8)" # gain 0.7
  -- Textural elements
  d3 $ loopAt 4 $ chop 16 
    $ s "ambient:4" # gain 0.8
```

IMPORTANT:

This does not work:

do
  setcps (120/60/4)
  -- Smooth kick and hat pattern
  d1 $ stack [
    s "808bd(3,8,<0 2>)" # n 3 # gain 1.1,
    s "~ 808oh ~ 808oh" # n 2 # gain 0.8 # room 0.3 # size 0.5
  ]
<--- you need to close the stack [ ] after the code.
It should be like this:
  d1 $ stack [
    s "808bd(3,8,<0 2>)" # n 3 # gain 1.1,
    s "~ 808oh ~ 808oh" # n 2 # gain 0.8 # room 0.3 # size 0.5 ]
