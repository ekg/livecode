/*
master-bus.scd — the master BUS, the control surface, and the meter. Nothing else.

WHY THIS FILE IS SEPARATE (and must NOT be hot-reloaded)
-------------------------------------------------------
It ALLOCATES buses (~masterBus, ~masterCtlBus, ~meterBus). Every mixer and orbit
in the session holds those bus INDICES. Re-running this file hands out new
indices and the session goes silent with no error — the failure mode that made
one evening of "the master chain is dead, meters at zero". So:

  * this file: buses + control surface + meter  — loaded once, at boot
  * sc/master-fx.scd: the FX chain + Ndef(\dubMaster) — allocates nothing,
    therefore safe to re-run on its own to change the FX

Chain (defined in master-fx.scd, played by init.scd AFTER the writers exist):

    orbits -> groups/mixers -> ~masterBus -> Ndef(\dubMaster) -> hardware
                                            (hpf -> gain -> [fx] -> ceiling)

Controls. The chain reads TWO of the eight bridged slots:
    slot [0] gain (default 1.0)      slot [5] hpf (default 48 Hz)
    slots [1][2][3][4][6][7] are kept so old preset files (house132/139/140,
    174-master) still RUN — they are reported inert instead of silently ignored.
*/
(
// ---------------------------------------------------------------- master controls
// [0] gain [1] glue [2] saturation [3] tone cut [4] duck depth [5] hpf
// [6] comp threshold [7] width     <- only [0] and [5] reach the audio
~masterCtlBus = Bus.control(s, 8);
~masterCtlBus.set(1.0, 0.55, 0.0, 20000, 0.0, 48, 0.05, 1.0);
// [0] rms  [1] envelope level  [2] level as a fraction of the ceiling
~meterBus = Bus.control(s, 3);
~meterBus.set(0, 0, 0);
~meterLog = Platform.userHomeDir ++ "/livecode/sc/master-meter.log";

// ---------------------------------------------------------------- master bus
~masterBus = Bus.audio(s, 2);
"master bus: %".format(~masterBus.index).postln;

// ---------------------------------------------------------------- surface
~masterVals = (mGain: 1.0, mGlue: 0.55, mSat: 0.0, mCut: 20000,
	mDuck: 0.0, mHpf: 48, mThresh: 0.05, mWidth: 1.0, mCeil: 0.89);
~masterInert = [\mGlue, \mSat, \mCut, \mDuck, \mThresh, \mWidth];
~masterSet = { |key, value|
	if(~masterVals[key].isNil) {
		("master: no such control: " ++ key).warn;
	} {
		~masterVals[key] = value;
		case
		{ key == \mGain } { ~masterCtlBus.setAt(0, value) }
		{ key == \mHpf } { ~masterCtlBus.setAt(5, value) }
		{ key == \mCeil } { Ndef(\dubMaster).set(\mCeil, value) }
		{ ~masterInert.includes(key) } {
			"master % = % (inert: the simplified master has no such stage)".format(key, value).postln;
		};
		"master % = %".format(key, value).postln;
	};
};

// the one knob that matters: master volume
~masterVol = { |g = 1.0|
	var v = g.clip(0.0, 40.0);
	~masterVals[\mGain] = v;
	~masterCtlBus.setAt(0, v);
	v;
};

// ---------------------------------------------------------------- meter
// log every 2s: rms, envelope level, and how much of the ceiling is used
if(~meterRoutine.notNil) { ~meterRoutine.stop };
~meterRoutine = Routine({
	var f = File(~meterLog, "w");
	loop {
		var values = ~meterBus.getnSynchronous(3);
		var rms = values[0];
		var peak = values[1];
		var use = values[2];
		var line = "%  peak %  rms %  ceiling-used %%%".format(
			Date.getDate.stamp, peak.round(0.001), rms.round(0.001),
			(use * 100).round(1));
		f.write(line ++ "\n"); f.flush;
		2.wait;
	};
}).play(AppClock);
"master-bus: bus % control % meter -> %".format(~masterBus.index, ~masterCtlBus.index, ~meterLog).postln;
~scLoadedMasterBus = true;  // sentinel: init.scd verifies this to catch a silent parse no-op
)
