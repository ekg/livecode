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
let d17 = p 17 :: ControlPattern -> IO ()
let d18 = p 18 :: ControlPattern -> IO ()
let d19 = p 19 :: ControlPattern -> IO ()
let d20 = p 20 :: ControlPattern -> IO ()
let d21 = p 21 :: ControlPattern -> IO ()
let d22 = p 22 :: ControlPattern -> IO ()
let d23 = p 23 :: ControlPattern -> IO ()
let d24 = p 24 :: ControlPattern -> IO ()
let d25 = p 25 :: ControlPattern -> IO ()
let d26 = p 26 :: ControlPattern -> IO ()
let d27 = p 27 :: ControlPattern -> IO ()
let d28 = p 28 :: ControlPattern -> IO ()
let d29 = p 29 :: ControlPattern -> IO ()
let d30 = p 30 :: ControlPattern -> IO ()
let d31 = p 31 :: ControlPattern -> IO ()
let d32 = p 32 :: ControlPattern -> IO ()
let d33 = p 33 :: ControlPattern -> IO ()
let d34 = p 34 :: ControlPattern -> IO ()
let d35 = p 35 :: ControlPattern -> IO ()
let d36 = p 36 :: ControlPattern -> IO ()
let d37 = p 37 :: ControlPattern -> IO ()
let d38 = p 38 :: ControlPattern -> IO ()
let d39 = p 39 :: ControlPattern -> IO ()
let d40 = p 40 :: ControlPattern -> IO ()
let d41 = p 41 :: ControlPattern -> IO ()
let d42 = p 42 :: ControlPattern -> IO ()
let d43 = p 43 :: ControlPattern -> IO ()
let d44 = p 44 :: ControlPattern -> IO ()
let d45 = p 45 :: ControlPattern -> IO ()
let d46 = p 46 :: ControlPattern -> IO ()
let d47 = p 47 :: ControlPattern -> IO ()
let d48 = p 48 :: ControlPattern -> IO ()
let _d17 = (\_ -> p 17 silence) :: ControlPattern -> IO ()
let _d18 = (\_ -> p 18 silence) :: ControlPattern -> IO ()
let _d19 = (\_ -> p 19 silence) :: ControlPattern -> IO ()
let _d20 = (\_ -> p 20 silence) :: ControlPattern -> IO ()
let _d21 = (\_ -> p 21 silence) :: ControlPattern -> IO ()
let _d22 = (\_ -> p 22 silence) :: ControlPattern -> IO ()
let _d23 = (\_ -> p 23 silence) :: ControlPattern -> IO ()
let _d24 = (\_ -> p 24 silence) :: ControlPattern -> IO ()
let _d25 = (\_ -> p 25 silence) :: ControlPattern -> IO ()
let _d26 = (\_ -> p 26 silence) :: ControlPattern -> IO ()
let _d27 = (\_ -> p 27 silence) :: ControlPattern -> IO ()
let _d28 = (\_ -> p 28 silence) :: ControlPattern -> IO ()
let _d29 = (\_ -> p 29 silence) :: ControlPattern -> IO ()
let _d30 = (\_ -> p 30 silence) :: ControlPattern -> IO ()
let _d31 = (\_ -> p 31 silence) :: ControlPattern -> IO ()
let _d32 = (\_ -> p 32 silence) :: ControlPattern -> IO ()
let _d33 = (\_ -> p 33 silence) :: ControlPattern -> IO ()
let _d34 = (\_ -> p 34 silence) :: ControlPattern -> IO ()
let _d35 = (\_ -> p 35 silence) :: ControlPattern -> IO ()
let _d36 = (\_ -> p 36 silence) :: ControlPattern -> IO ()
let _d37 = (\_ -> p 37 silence) :: ControlPattern -> IO ()
let _d38 = (\_ -> p 38 silence) :: ControlPattern -> IO ()
let _d39 = (\_ -> p 39 silence) :: ControlPattern -> IO ()
let _d40 = (\_ -> p 40 silence) :: ControlPattern -> IO ()
let _d41 = (\_ -> p 41 silence) :: ControlPattern -> IO ()
let _d42 = (\_ -> p 42 silence) :: ControlPattern -> IO ()
let _d43 = (\_ -> p 43 silence) :: ControlPattern -> IO ()
let _d44 = (\_ -> p 44 silence) :: ControlPattern -> IO ()
let _d45 = (\_ -> p 45 silence) :: ControlPattern -> IO ()
let _d46 = (\_ -> p 46 silence) :: ControlPattern -> IO ()
let _d47 = (\_ -> p 47 silence) :: ControlPattern -> IO ()
let _d48 = (\_ -> p 48 silence) :: ControlPattern -> IO ()
