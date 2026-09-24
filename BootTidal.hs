:set -fno-warn-orphans -Wno-type-defaults -XMultiParamTypeClasses -XOverloadedStrings
:set prompt ""

-- Import all the boot functions and aliases.
import Sound.Tidal.Boot

default (Rational, Integer, Double, Pattern String)

-- Create a Tidal Stream with the default settings.
-- To customize these settings, use 'mkTidalWith' instead
tidalInst <- mkTidal

instance Tidally where tidal = tidalInst

-- ============================================================================
-- Project-local parameters.
--
-- Tidal only sends params it knows about, so every custom SuperDirt parameter
-- must be declared here (step 1 of SuperDirt's "adding effects" recipe: declare
-- in Tidal, define a GlobalDirtEffect/SynthDef in SuperCollider). Without these
-- bindings an eval fails with "Variable not in scope: ddSend" before it ever
-- reaches the audio server.
--
-- These belong to the DSP layer in livecode/sc/ — see
-- pi-tidal/docs/sc-effects-and-routing.md
-- ============================================================================

-- dub delay (dirt_dubdelay)
let ddSend   = pF "ddSend"
    ddLp     = pF "ddLp"
    ddHp     = pF "ddHp"
    ddDrive  = pF "ddDrive"
    ddWow    = pF "ddWow"
    ddCross  = pF "ddCross"
    ddDuck   = pF "ddDuck"

-- dub reverb (dirt_dubverb)
    verbSend    = pF "verbSend"
    verbT60     = pF "verbT60"
    verbDamp    = pF "verbDamp"
    verbEarly   = pF "verbEarly"
    verbHp      = pF "verbHp"
    verbPre     = pF "verbPre"
    verbLow     = pF "verbLow"
    verbHigh    = pF "verbHigh"
    verbLowcut  = pF "verbLowcut"
    verbHighcut = pF "verbHighcut"
    verbTone    = pF "verbTone"
    verbMod     = pF "verbMod"
    verbWidth   = pF "verbWidth"

-- master chain (dirt_masterctl -> Ndef(\dubMaster))
    mGain   = pF "mGain"
    mGlue   = pF "mGlue"
    mSat    = pF "mSat"
    mCut    = pF "mCut"
    mDuck   = pF "mDuck"
    mHpf    = pF "mHpf"
    mThresh = pF "mThresh"
    mWidth  = pF "mWidth"

-- per-event tape module (dirt_tape)
    tape     = pF "tape"
    tapeWow  = pF "tapeWow"
    tapeHf   = pF "tapeHf"
    tapeHiss = pF "tapeHiss"

-- instrument voicing (dubchord / dubsub / tapestab)
    cutoff  = pF "cutoff"
    fenv    = pF "fenv"
    res     = pF "res"
    drive   = pF "drive"
    sub     = pF "sub"
    spread  = pF "spread"
    attack  = pF "attack"
    pitchEnv = pF "pitchEnv"

:set prompt "tidal> "
:set prompt-cont ""
