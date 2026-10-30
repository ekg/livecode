:set -fno-warn-orphans -Wno-type-defaults -XMultiParamTypeClasses -XOverloadedStrings
:set prompt ""

-- Import all the boot functions and aliases.
import Sound.Tidal.Boot

default (Rational, Integer, Double, Pattern String)

-- Create a Tidal Stream with the default settings.
-- To customize these settings, use 'mkTidalWith' instead
tidalInst <- mkTidal

instance Tidally where tidal = tidalInst

-- BEGIN GENERATED PARAMS (tools/sc_params.py from sc/params.tsv)
-- One binding per line: a multi-line `let` block is silently dropped
-- when the file is loaded from a ghci script (-ghci-script).

-- dirt_dubdelay
let ddSend = pF "ddSend"
let ddLp = pF "ddLp"
let ddHp = pF "ddHp"
let ddDrive = pF "ddDrive"
let ddWow = pF "ddWow"
let ddCross = pF "ddCross"
let ddDuck = pF "ddDuck"
let delaytime = pF "delaytime"
let delayfeedback = pF "delayfeedback"
let delaySend = pF "delaySend"
let lock = pI "lock"
let cps = pF "cps"

-- dirt_dubverb
let verbSend = pF "verbSend"
let room = pF "room"
let verbT60 = pF "verbT60"
let verbDamp = pF "verbDamp"
let size = pF "size"
let verbEarly = pF "verbEarly"
let verbHp = pF "verbHp"
let verbPre = pF "verbPre"
let verbLow = pF "verbLow"
let verbHigh = pF "verbHigh"
let verbLowcut = pF "verbLowcut"
let verbHighcut = pF "verbHighcut"
let verbTone = pF "verbTone"
let verbMod = pF "verbMod"
let verbWidth = pF "verbWidth"

-- dirt_tape
let tape = pF "tape"
let tapeWow = pF "tapeWow"
let tapeHf = pF "tapeHf"
let tapeHiss = pF "tapeHiss"

-- dirt_monitor
let limitertype = pI "limitertype"

-- instrument
let cutoff = pF "cutoff"
let fenv = pF "fenv"
let res = pF "res"
let drive = pF "drive"
let sub = pF "sub"
let spread = pF "spread"
let attack = pF "attack"
let pitchEnv = pF "pitchEnv"
let detune = pF "detune"
let fmix = pF "fmix"
let wavemix = pF "wavemix"
let vib = pF "vib"
let vibRate = pF "vibRate"
let trem = pF "trem"
let tremRate = pF "tremRate"
let keyShift = pF "keyShift"

-- dubsynth
let waveMix = pF "waveMix"
let subMix = pF "subMix"
let subTone = pF "subTone"
let spread = pF "spread"

-- miLead
let engine = pI "engine"
let harm = pF "harm"
let timbre = pF "timbre"
let morph = pF "morph"
let level = pF "level"
let lpgColour = pF "lpgColour"

-- sweetChords
let fmIndex = pF "fmIndex"
let ratio = pF "ratio"
let drive = pF "drive"
let sub = pF "sub"
let width = pF "width"

-- master_inert
let mGain = pF "mGain"
let mGlue = pF "mGlue"
let mSat = pF "mSat"
let mCut = pF "mCut"
let mDuck = pF "mDuck"
let mHpf = pF "mHpf"
let mThresh = pF "mThresh"
let mWidth = pF "mWidth"

-- END GENERATED PARAMS

:set prompt "tidal> "
:set prompt-cont ""

-- EXTENDED STREAMS. Sound.Tidal.Boot defines d1..d16 only; they are just
-- `p n . (|< orbit k)` aliases, and `p` is exported, so more are free.
-- One binding per line: a multi-line let block is silently dropped by -ghci-script.
-- Streams are NOT orbits: a stream can target any orbit via # orbit N, so
-- the stream count limits simultaneous patterns, not FX slots.
let d17 = p 17
let d18 = p 18
let d19 = p 19
let d20 = p 20
let d21 = p 21
let d22 = p 22
let d23 = p 23
let d24 = p 24
let d25 = p 25
let d26 = p 26
let d27 = p 27
let d28 = p 28
let d29 = p 29
let d30 = p 30
let d31 = p 31
let d32 = p 32
let d33 = p 33
let d34 = p 34
let d35 = p 35
let d36 = p 36
let d37 = p 37
let d38 = p 38
let d39 = p 39
let d40 = p 40
let d41 = p 41
let d42 = p 42
let d43 = p 43
let d44 = p 44
let d45 = p 45
let d46 = p 46
let d47 = p 47
let d48 = p 48
let _d17 = _p 17
let _d18 = _p 18
let _d19 = _p 19
let _d20 = _p 20
let _d21 = _p 21
let _d22 = _p 22
let _d23 = _p 23
let _d24 = _p 24
let _d25 = _p 25
let _d26 = _p 26
let _d27 = _p 27
let _d28 = _p 28
let _d29 = _p 29
let _d30 = _p 30
let _d31 = _p 31
let _d32 = _p 32
let _d33 = _p 33
let _d34 = _p 34
let _d35 = _p 35
let _d36 = _p 36
let _d37 = _p 37
let _d38 = _p 38
let _d39 = _p 39
let _d40 = _p 40
let _d41 = _p 41
let _d42 = _p 42
let _d43 = _p 43
let _d44 = _p 44
let _d45 = _p 45
let _d46 = _p 46
let _d47 = _p 47
let _d48 = _p 48
