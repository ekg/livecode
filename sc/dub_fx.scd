/*
dub_fx.scd — global effects + per-event modules + instruments.

Bus conventions (from SuperDirt's own core-synths-global.scd):
  SEND effects    : read dryBus, write the wet signal to effectBus
                    (the monitor sums dryBus + effectBus)
  INSERT effects  : read effectBus, ReplaceOut it
  GLOBAL effects  : instantiated per orbit as  Synth(name ++ numChannels, [outBus, dryBus, effectBus, orbitIndex, ...params])
  PER-EVENT module: Synth called with ~out as the event's own bus, In.ar(out) -> ReplaceOut.ar(out)

Why these exist: SuperDirt's stock dirt_reverb feeds the whole dry signal into a
lowpass-in-the-loop reverb with no high-pass and no pre-delay, and every layer
sends to it by default. That is the "reverb all over everything" sound: the low
end of every hit piles into one undamped tail. These replacements are the
standard fixes (HPF the send at 200-400 Hz, 10-50 ms pre-delay, damp the tail,
short low-band reverb time), plus a dub delay whose repeats darken and never
boom, and a tape module for lo-fi character.
*/
(
var build = { |n, sfx|

	// ---------------------------------------------------------------- SEND: reverb
	SynthDef("dirt_dubverb" ++ sfx, { |dryBus, effectBus,
		verbSend = 0, room = 0,                 // `room` kept for compatibility
		verbT60 = 6, verbDamp = 0.55, size = 0.9, verbEarly = 0.85,
		verbHp = 320, verbPre = 0.03,           // HPF the send, pre-delay the wet
		verbLow = 0.35, verbHigh = 0.9,         // low band decays faster -> no mud
		verbLowcut = 400, verbHighcut = 7000,
		verbTone = 9000, verbMod = 0.3, verbWidth = 1|
		var dry = In.ar(dryBus, n);
		var send = max(verbSend, room).lag(0.2);
		var mono = dry.asArray.sum / n;
		var src = HPF.ar(mono * send, verbHp);
		var pre = DelayN.ar(src, 0.2, verbPre.lag(0.1));
		var wet = JPverb.ar(pre,
			t60: verbT60, damp: verbDamp, size: size, earlyDiff: verbEarly,
			modDepth: verbMod, modFreq: 0.5,
			low: verbLow, mid: 1.0, high: verbHigh,
			lowcut: verbLowcut, highcut: verbHighcut);
		wet = LPF.ar(wet, verbTone);
		wet = Splay.ar(wet.asArray, 0.6) * verbWidth;
		Out.ar(effectBus, wet);
	}).add;

	// ---------------------------------------------------------------- SEND: dub delay
	SynthDef("dirt_dubdelay" ++ sfx, { |dryBus, effectBus,
		ddSend = 0,                             // send amount (0 = off)
		delaytime = 0.375, delayfeedback = 0.45, delaySend = 1,  // compatible with dirt_delay params
		ddLp = 2600, ddHp = 220,                // repeats get darker, never boom
		ddDrive = 0.25, ddWow = 0.12, ddCross = 0.6,
		ddDuck = 0.45,                          // wet ducks under new hits (classic dub)
		lock = 0, cps = 1|
		var dry = In.ar(dryBus, n);
		var send = ddSend.lag(0.1) * delaySend;
		// NOTE: `if` cannot take a UGen condition inside a SynthDef — that is a
		// build-time error ("Non Boolean in test"). Select.kr is the UGen-safe
		// branch. lock=1 scales the delay time to the cycle length (dub lock).
		var lockScale = Select.kr(lock.round.clip(0, 1), [1, reciprocal(cps.max(0.001))]);
		var dt = (delaytime * lockScale).clip(0.02, 2.5);
		var wow = SinOsc.kr([0.21, 0.33], [0, pi]).range(1 - ddWow, 1 + ddWow);
		// LocalIn/In.ar return a bare UGen when n == 1, so normalise to an array
		// before any array op (`reverse` on an OutputProxy is a hard error).
		var fb = LocalIn.ar(n).asArray;
		var input = (dry.asArray * send) + (fb.reverse * (1 - ddCross)) + (fb * ddCross);
		var tap = DelayC.ar(input, 2.6, dt * wow);
		tap = LPF.ar(HPF.ar(tap, ddHp), ddLp);
		tap = (tap * (1 + (ddDrive * 5))).tanh / (1 + (ddDrive * 1.6));
		LocalOut.ar(tap * delayfeedback.clip(0, 0.94));
		tap = tap * (1 - (ddDuck * Amplitude.kr(dry.asArray.sum / n, 0.004, 0.12).clip(0, 1)));
		Out.ar(effectBus, tap);
	}).add;

	// ------------------------------------------------- INSERT: per-event tape (lo-fi)
	SynthDef("dirt_tape" ++ sfx, { |out, tape = 1, tapeHf = 6500, tapeHiss = 0.015, tapeWow = 0.3|
		var sig = In.ar(out, n);
		var wob = SinOsc.kr([0.6, 0.83], [0, 1.3]).range(1 - (tapeWow * 0.002), 1 + (tapeWow * 0.002));
		sig = DelayC.ar(sig, 0.02, (0.004 * wob).clip(0.0005, 0.02));
		sig = (sig * (1 + (tape * 4))).tanh / (1 + (tape * 1.4));
		sig = LPF.ar(sig, tapeHf.lag(0.1));
		sig = sig + (PinkNoise.ar(tapeHiss) * 0.5);
		ReplaceOut.ar(out, sig);
	}).add;

	// ------------------------------------------------------------ instrument: dub chord
	SynthDef("dubchord" ++ sfx, { |out, freq = 220, sustain = 1, pan = 0,
		detune = 0.14, cutoff = 700, fenv = 3.2, res = 0.35, drive = 0.35,
		sub = 0.35, spread = 0.7, attack = 0.004, amp = 0.5,
		speed = 1, accelerate = 0, sustain2|
		var env = EnvGen.kr(Env.linen(attack, sustain * 0.65, sustain * 2.4, 1, -3), doneAction: 2);
		var fmod = EnvGen.kr(Env.perc(0.002, 0.28), levelScale: fenv);
		var base = freq * DirtFreqScale.kr(speed, accelerate, sustain);
		var osc = Saw.ar(base * [0.5, 1 - detune, 1, 1 + detune]) * [0.5, 0.7, 1, 0.7];
		var sig = osc.sum;
		sig = RLPF.ar(sig, (cutoff * (1 + fmod)).clip(40, 17000), res.clip(0.05, 0.95));
		sig = (sig * (1 + (drive * 4))).tanh * 0.4;
		sig = sig + (SinOsc.ar(base * 0.5) * sub);
		sig = sig * env * amp;
		sig = if(n == 1) { sig.asArray.sum } { Splay.ar(sig.asArray, spread) };
		Out.ar(out, DirtPan.ar(sig, n, pan));
	}).add;

	// ---------------------------------------------------------------- instrument: sub
	SynthDef("dubsub" ++ sfx, { |out, freq = 55, sustain = 1, pan = 0,
		drive = 0.45, amp = 0.8, pitchEnv = 0.6, decay2 = 0.1,
		speed = 1, accelerate = 0|
		var env = EnvGen.kr(Env.linen(0.008, sustain * 0.8, sustain * 1.8, 1, -4), doneAction: 2);
		var f = freq * DirtFreqScale.kr(speed, accelerate, sustain)
			* (1 + (EnvGen.kr(Env.perc(0.002, 0.12)) * pitchEnv));
		var sig = SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.12);
		sig = (sig * (1 + (drive * 5))).tanh;
		sig = sig * env * amp;
		Out.ar(out, DirtPan.ar(sig, n, pan));
	}).add;

	// -------------------------------------------------------- instrument: tape stab
	SynthDef("tapestab" ++ sfx, { |out, freq = 440, sustain = 0.3, pan = 0,
		cutoff = 1800, res = 0.4, drive = 0.5, amp = 0.4,
		speed = 1, accelerate = 0|
		var env = EnvGen.kr(Env.perc(0.002, sustain * 2.2, 1, -4), doneAction: 2);
		var base = freq * DirtFreqScale.kr(speed, accelerate, sustain);
		var sig = LFTri.ar(base) + (Saw.ar(base * 1.005) * 0.6);
		sig = RLPF.ar(sig, cutoff, res.clip(0.05, 0.95));
		sig = (sig * (1 + (drive * 4))).tanh * 0.5;
		sig = sig * env * amp;
		sig = if(n == 1) { sig.asArray.sum } { Splay.ar(sig.asArray, 0.4) };
		Out.ar(out, DirtPan.ar(sig, n, pan));
	}).add;
};

// stereo is what the orbits use; mono keeps instruments usable by mono samples.
// Global effects are looked up as  name ++ numChannels  (SuperDirt's convention),
// while instruments played via  s "name"  resolve by the bare name, so define both.
[1, 2].do { |n| build.(n, n) };   // dirt_dubverb1/2, dubchord1/2, ...
build.(2, "");                     // dubchord, dubsub, tapestab (stereo, unsuffixed)
"dub_fx: dubverb, dubdelay, tape, dubchord, dubsub, tapestab defined".postln;
)
