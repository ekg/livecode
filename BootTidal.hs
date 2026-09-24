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
