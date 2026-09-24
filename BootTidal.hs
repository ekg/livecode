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
-- Project-local parameters for the SuperCollider DSP layer in livecode/sc/.
--
-- Tidal only sends params it knows about, so every custom SuperDirt parameter
-- has to be declared here (step 1 of SuperDirt's "adding effects" recipe).
-- See pi-tidal/docs/sc-effects-and-routing.md
--
-- NOTE: one binding per line. A multi-line `let` block does not survive being
-- loaded from a ghci script — the continuation lines are parsed as separate
-- commands, every binding after the first is silently dropped, and evals then
-- fail with "Variable not in scope: ddSend" while the REPL looks healthy.
-- ============================================================================

let ddSend = pF "ddSend"
let ddLp = pF "ddLp"
let ddHp = pF "ddHp"
let ddDrive = pF "ddDrive"
let ddWow = pF "ddWow"
let ddCross = pF "ddCross"
let ddDuck = pF "ddDuck"

let verbSend = pF "verbSend"
let verbT60 = pF "verbT60"
let verbDamp = pF "verbDamp"
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

let mGain = pF "mGain"
let mGlue = pF "mGlue"
let mSat = pF "mSat"
let mCut = pF "mCut"
let mDuck = pF "mDuck"
let mHpf = pF "mHpf"
let mThresh = pF "mThresh"
let mWidth = pF "mWidth"

let tape = pF "tape"
let tapeWow = pF "tapeWow"
let tapeHf = pF "tapeHf"
let tapeHiss = pF "tapeHiss"

let cutoff = pF "cutoff"
let fenv = pF "fenv"
let res = pF "res"
let drive = pF "drive"
let sub = pF "sub"
let spread = pF "spread"
let attack = pF "attack"
let pitchEnv = pF "pitchEnv"

:set prompt "tidal> "
:set prompt-cont ""
