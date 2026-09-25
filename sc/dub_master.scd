/*
dub_master.scd — master bus, master effects chain, and Tidal-reachable controls.

Architecture
------------
  every orbit --(its own sends: dubdelay, dubverb)--> its dirt_monitor
        dirt_monitor writes to  ~masterBus   (orbit.outBus = ~masterBus)
                                          |
                                     Ndef(\dubMaster)
        high-pass -> glue compressor (ducked by the kick) -> tape saturation
                  -> tone filter -> soft limiter -> hardware out

Why a master chain at all: with every orbit writing straight to the sound card
there is nowhere for the mix to "glue" — each layer is finished on its own and
their sum is whatever it happens to be. Routing them into one bus gives a single
place to sit them together (and the kick can duck the whole bus, which is what
makes a lo-fi dub mix breathe instead of pile up).

Controls are exposed to Tidal through a control bus: a global effect
(`dirt_masterctl`) writes the params carried by any event into ~masterCtlBus, and
the Ndef reads them. So from Tidal:

    d1 $ s "bd(3,8)" # mGlue 0.7 # mSat 0.45 # mCut 9000 # mDuck 0.35

Any event carrying those params updates the master. Values lag, so changes glide.
*/
(
var n = 2;

// ---------------------------------------------------------------- master controls
// [0] gain [1] glue [2] saturation [3] tone cut [4] duck depth [5] hpf
// [6] comp threshold [7] width
~masterCtlBus = Bus.control(s, 8);
// [0] peak follower  [1] rms  [2] gain reduction estimate — the ceiling, visible
~meterBus = Bus.control(s, 3);
~meterBus.set(0, 0, 0);
~meterLog = Platform.userHomeDir ++ "/livecode/sc/master-meter.log";
// Master settings, sclang-side (see the note at the end of this file: the
// Tidal-side m* control bridge does not reach the chain reliably, so the master
// is configured here and the music is driven through the per-orbit sends).
// [gain, glue, sat, tone, duck, hpf, thresh, width]
~masterCtlBus.set(0.9, 0.6, 0.28, 13000, 0.3, 28, 0.4, 0.9);

// ---------------------------------------------------------------- master bus
~masterBus = Bus.audio(s, n);
"master bus: %".format(~masterBus.index).postln;

// ---------------------------------------------------- global effect: param bridge
// pass-through audio; just ferries Tidal params into the control bus
[1, 2].do { |ch|
	SynthDef("dirt_masterctl" ++ ch, { |effectBus,
		mGain = 1.0, mGlue = 0.55, mSat = 0.3, mCut = 14000, mDuck = 0.3,
		mHpf = 25, mThresh = 0.35, mWidth = 1.0|
		var sig = In.ar(effectBus, ch);
		var ctl = ~masterCtlBus;
		// keep a floor under the gain: a single stray event must not be able to
		// mute the whole mix (silence with no error is the worst failure mode)
		Out.kr(ctl.index,
			[mGain.clip(0.25, 2), mGlue, mSat, mCut, mDuck, mHpf, mThresh, mWidth]);
		ReplaceOut.ar(effectBus, sig);
	}).add;
};

// ---------------------------------------------------------------- master chain
Ndef(\dubMaster, {
	// Controls live ON the Ndef itself (\mGain.kr(...)), not behind a control bus
	// that the Ndef reads. The bus version silently did nothing: writing the bus
	// never changed the audio (measured: master bus gain 0.3 vs 1.0 made no
	// difference), which is also why the Tidal m* params appeared dead.
	var gain = \mGain.kr(0.9, 0.2);
	var glue = \mGlue.kr(0.42, 0.2);   // was 0.6: smaller slopeAbove = more compression
	var sat = \mSat.kr(0.34, 0.2);
	var cut = \mCut.kr(13000, 0.5);
	var duckAmt = \mDuck.kr(0.38, 0.2);
	var hpfF = \mHpf.kr(28, 0.5);
	var thresh = \mThresh.kr(0.28, 0.2);  // was 0.4: compress earlier
	var width = \mWidth.kr(0.9, 0.2);

	var dry = In.ar(~masterBus, n);
	// sidechain: orbit 0 is the drum orbit by convention (d1's default orbit)
	var kick = In.ar(~dirt.orbits[0].dryBus, n).asArray.sum;
	var duck = duckAmt * Amplitude.kr(kick, 0.004, 0.12).clip(0, 1);

	var ceil = \mCeil.kr(0.79, 0.2);      // ≈ -2.1 dBFS sample ceiling (our material
	                                      // overshoots ~1.1 dB between samples)
	var knee = \mKnee.kr(0.55, 0.2);      // soft-clip knee (amplitude, not a ratio)
	var sig = HPF.ar(dry, hpfF);
	sig = Compander.ar(sig, sig,
		thresh: thresh, slopeBelow: 1, slopeAbove: glue.max(0.05),
		clampTime: 0.008, relaxTime: 0.22);
	sig = (sig * (1 + (sat * 6))).tanh / (1 + (sat * 2));
	sig = LPF.ar(sig, cut);
	sig = sig * (1 - (duck * 0.85));
	sig = sig * gain;

	// ---- ceiling ------------------------------------------------------------
	// soft knee first: transients get rounded rather than slammed, which is what
	// makes a loud master sound open instead of squashed
	// tanh soft knee: linear below `knee`, saturating above it.
	// NB: SC's `softclip` takes NO knee argument — `sig.softclip(0.35)` was parsed
	// as a multiplier and quietly scaled the entire master by 0.35 (≈ -9 dB).
	sig = (sig / knee).tanh * knee;
	// look-ahead limiter: musical gain control (measured: it does NOT strictly
	// bound — peaks of 0.865 passed a 0.79 "level", so it is a soft-ish limiter)
	sig = Limiter.ar(sig, ceil, 0.01);
	// GUARANTEED ceiling, so nothing can exceed it whatever the limiter does
	sig = sig.clip2(ceil);
	// Metering that can actually be trusted:
	//  * slot 0 = true RMS over a ~250 ms window  ((sig^2) smoothed, then sqrt —
	//    PeakFollower with a slow decay only ever holds the maximum, which is why
	//    the meter appeared "pinned at the ceiling" and told us nothing)
	//  * slot 1 = envelope with fast attack / 150 ms release (a level reading)
	//  * slot 2 = that level as a fraction of the ceiling
	var rms = (sig.asArray.collect { |c| c * c }.sum / sig.asArray.size).lag(0.25).sqrt;
	var lvl = Amplitude.kr(sig.asArray.sum / sig.asArray.size, 0.002, 0.15);
	Out.kr(~meterBus.index + 0, rms);
	Out.kr(~meterBus.index + 1, lvl);
	Out.kr(~meterBus.index + 2, (lvl / ceil.max(0.001)).clip(0, 2));
	// Ndef writes the returned signal to its own output bus (0/1 = hardware),
	// so do NOT also Out.ar here — that would double the mix.
	Splay.ar(sig.asArray, width.clip(0, 1).linlin(0, 1, 0.2, 1.0));
}).play;

// keep sclang-side access to the same values: this Event is the source of truth
// for the surface, and Ndef.set is what actually reaches the audio
~masterVals = (mGain: 0.9, mGlue: 0.42, mSat: 0.34, mCut: 13000,
	mDuck: 0.38, mHpf: 28, mThresh: 0.28, mWidth: 0.9, mCeil: 0.79, mKnee: 0.35);
~masterSet = { |key, value|
	if(~masterVals[key].isNil) {
		("master: no such control: " ++ key).warn;
	} {
		~masterVals[key] = value;
		Ndef(\dubMaster).set(key, value);
		"master % = %".format(key, value).postln;
	};
};

// log the meter every 2s: peaks, rms, and how much of the ceiling is used
if(~meterRoutine.notNil) { ~meterRoutine.stop };
~meterRoutine = Routine({
	var f = File(~meterLog, "w");
	loop {
		var peak = ~meterBus.getSynchronous(0);
		var rms = ~meterBus.getSynchronous(1);
		var use = ~meterBus.getSynchronous(2);
		var line = "%  peak %  rms %  ceiling-used %%%".format(
			Date.getDate.stamp, peak.round(0.001), rms.round(0.001),
			(use * 100).round(1));
		f.write(line ++ "\n"); f.flush;
		2.wait;
	};
}).play(AppClock);
"dub_master: chain running (hpf -> glue -> tape -> tone -> duck -> knee -> limiter)".postln;
"dub_master: ceiling meter -> %  (every 2s)".format(~meterLog).postln;
)
