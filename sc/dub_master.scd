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
~masterCtlBus.set(1.0, 0.55, 0.3, 14000, 0.3, 25, 0.35, 1.0);

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
	var ctl = ~masterCtlBus.index;
	var gain = In.kr(ctl + 0, 1).clip(0.25, 2);
	var glue = In.kr(ctl + 1, 1);
	var sat = In.kr(ctl + 2, 1);
	var cut = In.kr(ctl + 3, 1);
	var duckAmt = In.kr(ctl + 4, 1);
	var hpfF = In.kr(ctl + 5, 1);
	var thresh = In.kr(ctl + 6, 1);
	var width = In.kr(ctl + 7, 1);

	var dry = In.ar(~masterBus, n);
	// sidechain: orbit 0 is the drum orbit by convention (d1's default orbit)
	var kick = In.ar(~dirt.orbits[0].dryBus, n).sum;
	var duck = duckAmt * Amplitude.kr(kick, 0.004, 0.12).clip(0, 1);

	var sig = HPF.ar(dry, hpfF.lag(0.5));
	sig = Compander.ar(sig, sig,
		thresh: thresh, slopeBelow: 1, slopeAbove: glue.max(0.05),
		clampTime: 0.008, relaxTime: 0.22);
	sig = (sig * (1 + (sat * 6))).tanh / (1 + (sat * 2));
	sig = LPF.ar(sig, cut.lag(0.5));
	sig = sig * (1 - (duck * 0.85));
	sig = sig * gain;
	sig = Limiter.ar(sig, 0.96, 0.01);
	// Ndef writes the returned signal to its own output bus (0/1 = hardware),
	// so do NOT also Out.ar here — that would double the mix.
	Splay.ar(sig.asArray, width.clip(0, 1).linlin(0, 1, 0.2, 1.0));
}).play;

"dub_master: chain running (hpf -> glue -> tape -> tone -> duck -> limiter)".postln;
)
