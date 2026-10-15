/*
master-fx.scd — the master FX chain and Ndef(\dubMaster). Hot-reloadable.

WHY THIS FILE IS SEPARATE
-------------------------
It ALLOCATES NOTHING (no Bus). It defines a SynthDef, one chain FUNCTION, and the
Ndef. So it can be re-run at any time to change the FX while the track is
playing — which is what you want when the FX are the thing being edited, and it
is exactly what could NOT be done with the old single dub_master.scd (whose top
half handed out new bus indices on every run).

    ~/livecode/sc/master-bus.scd   buses + gain + meter   -> once, at boot
    ~/livecode/sc/master-fx.scd    FX chain + Ndef         -> re-runnable

Re-running this file loses FX param values (the Ndef is rebuilt with its declared
defaults). That is the whole cost, and it is cheaper than a silent session.

    ==> AFTER RE-RUNNING IT, RE-TAIL THE READER (see ~masterReTail below). <==

THE CHAIN
---------
    ~masterBus -> hpf -> gain -> [~masterFxChain] -> ceiling clip -> hardware

DRY BY DEFAULT. ~masterFxChain returns its input UNCHANGED. The default master is
three stages and no character: hpf -> gain -> clip. There is no always-on
nonlinearity, no always-on modulated reverb, no compressor and no duck on the
master (the old chain ran a feedback delay with a tanh saturator, a kick-driven
duck, a glue compressor and a tone filter on every sample of every bar — heard at
the desk as "vibrating / crunchy / weird").

!! DO NOT PUT LocalIn/LocalOut IN THIS Ndef !!
---------------------------------------------
Measured 2026-10-15: an FX helper whose feedback ring used LocalIn.ar/LocalOut.ar,
called from inside Ndef(\dubMaster), built with NO error and produced EXACT
silence — hardware bus 0.0, the Ndef's own meter pinned at 0.0, while the input
bus measured real signal. The failures it looks like are "reader runs before the
writers" or "the mixers are muted"; it is neither, and both of those send you
hunting in the wrong subsystem for a long time.
If you want a feedback/delay insert, do it as a BUS-BASED send/return: allocate
the send bus in master-bus.scd (which is allowed to allocate) and run the
feedback in a separate Synth, not inside this Ndef.

MODULATING AN FX PROPERLY (the pattern to copy)
-----------------------------------------------
1. Parameters are declared .kr ON the Ndef with an explicit LAG:
       \fxTone.kr(18000, 0.4)
   The lag is the point: a knob moved by Tidal (or a slow LFO) arrives as a ramp,
   never a step, so nothing clicks and nothing chatters.
2. Declared once, in one place, with a documented range.
3. Nonlinearities (tanh/softclip/FreeVerb) stay INSIDE an opt-in insert, never on
   the always-on path, so "no FX" is exactly the dry signal.
4. Write with ~masterFxSet.(\fxTone, 4000) and read with ~masterFxGet.(\fxTone) —
   no control bus to leak, nothing to keep in step.
*/
(
// ---------------------------------------------------- global effect: param bridge
// pass-through audio; ferries Tidal's m* params into ~masterCtlBus. Kept so old
// scenes that send m* params still compile; unused slots simply do nothing.
[1, 2].do { |ch|
	SynthDef("dirt_masterctl" ++ ch, { |effectBus,
		mGain = 1.0, mGlue = 0.55, mSat = 0.0, mCut = 20000, mDuck = 0.0,
		mHpf = 48, mThresh = 0.05, mWidth = 1.0|
		var sig = In.ar(effectBus, ch);
		Out.kr(~masterCtlBus.index,
			[mGain.clip(0.05, 40), mGlue, mSat, mCut, mDuck,
			 mHpf.clip(10, 400), mThresh, mWidth]);
		ReplaceOut.ar(effectBus, sig);
	}).add;
};

// ---------------------------------------------------- the chain
// A plain, feedback-free insert point. It ships as the IDENTITY: one optional
// low-pass, wide open by default, so the master is exactly hpf -> gain -> clip.
// Add anything you like here as long as it is acyclic (see the LocalIn warning
// at the top of this file) and behind a lagged control that defaults to "off".
~masterFxChain = { |sig|
	var tone = \fxTone.kr(18000, 0.4).clip(100, 20000);
	LPF.ar(sig, tone);
};

// ---------------------------------------------------- the master Ndef
Ndef(\dubMaster, {
	// NB: bus INDICES, not Bus objects — In.ar(Bus, n) builds a broken synth that
	// compiles fine and passes nothing (the "master chain dead" failure: Ndef
	// playing, meter zero, hardware silent)
	var ctl = In.kr(~masterCtlBus.index, 8);
	var gain = ctl[0].lag(0.05);
	var hpfF = ctl[5].lag(0.2);
	var ceil = \mCeil.kr(0.89, 0.2);   // hard safety ceiling, NOT a musical limiter
	// NB: var declarations MUST come before every other statement in a function
	// body. A parse error in a file run through executeFile is SILENT: no error,
	// executeFile returns nil, and the whole file is a no-op.
	var rms, lvl;
	var dry = In.ar(~masterBus.index, 2);
	var sig = HPF.ar(dry, hpfF);
	sig = sig * gain;
	sig = ~masterFxChain.value(sig);
	sig = sig.clip2(ceil);
	// Metering: slot 0 = true RMS (~250 ms window), 1 = envelope level, 2 = that
	// level as a fraction of the ceiling.
	rms = (sig.asArray.collect { |c| c * c }.sum / sig.asArray.size).lag(0.25).sqrt;
	lvl = Amplitude.kr(sig.asArray.sum / sig.asArray.size, 0.002, 0.15);
	Out.kr(~meterBus.index + 0, rms);
	Out.kr(~meterBus.index + 1, lvl);
	Out.kr(~meterBus.index + 2, (lvl / ceil.max(0.001)).clip(0, 2));
	// NB: defined here, but NOT played here — init.scd plays it AFTER the mixing
	// strips exist: scsynth zeroes internal buses at the start of each control
	// cycle, so the master reader must run after the writers. Return AUDIO.
	Splay.ar(sig.asArray, 1.0);
});

// ---------------------------------------------------- reader placement
// scsynth zeroes internal buses at the start of every control cycle, so a node
// reading ~masterBus must sit AFTER whatever writes it. Whatever group that is
// depends on who is mixing: the legacy group strips live in the dirt group, but
// a loaded SCENE's mixers live in ~piSceneManager[\group]. Put the reader at the
// tail of whichever of those actually exists.
~masterReTail = {
	var head = if(~piSceneManager.notNil and: { ~piSceneManager[\group].notNil },
		{ ~piSceneManager[\group].nodeID }, { ~dirt.group.nodeID });
	s.sendMsg("/g_tail", head, Ndef(\dubMaster).group.nodeID);
	Ndef(\dubMaster).play;
	("master reader re-tailed into group % (after the writers)".format(head)).postln;
};

// ---------------------------------------------------- FX surface
~masterFxSet = { |key, value| Ndef(\dubMaster).set(key, value); ~masterVals[key] = value; };
~masterFxGet = { |key| Ndef(\dubMaster).get(key) };
~masterFxDefault = (fxTone: 18000, mCeil: 0.89);

"master-fx: chain defined, DRY by default (hpf -> gain -> clip; fxTone wide open)".postln;
"master-fx: run ~masterReTail.value AFTER this file to re-place the reader".postln;
~scLoadedMasterFx = true;  // sentinel: init.scd verifies this to catch a silent parse no-op
)
