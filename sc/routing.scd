/*
routing.scd — a mixing/routing layer above SuperDirt's orbits.

Until now every orbit fed one master bus, which is a single knob: you can only
turn the whole mix up or down. Soundscape work needs *structure*:

    orbit (source)  ->  GROUP bus  ->  group processing  ->  master
                             |
                             +--> AUX sends (delay / reverb / shimmer)
                                              |
                                              +--> returns -> master

So this adds what a mixing desk would: group buses, post-fader aux sends with
returns, a sidechain (kick ducks the reverb return and the master), a feedback
network for evolving tails (Greyhole: dub-style modulated delay-verb), and a
stereo-width/decorrelation stage on the music group.

Everything here is additive and guarded: if it fails, orbits stay on the master
bus (the previously verified state) and audio keeps working. Send levels live on
control buses so they can be modulated from SuperCollider (and from Tidal, once
the master-control bridge is rebuilt properly — see
pi-tidal/docs/sc-effects-and-routing.md).

Group assignment is by orbit index, and can be changed at runtime:
    ~route.orbit(2, \music)          // move orbit 2 into the music group
    ~route.send(\music, \delay, 0.6) // send level from one group to one aux
    ~route.levels                    // inspect the current map
*/
(
var n = 2;

// ---------------------------------------------------------------- buses
~groups = (
	drums: Bus.audio(s, n),
	bass:  Bus.audio(s, n),
	music: Bus.audio(s, n),
	fx:    Bus.audio(s, n),
);
~aux = (
	delay:   Bus.audio(s, n),
	verb:    Bus.audio(s, n),
	shimmer: Bus.audio(s, n),
);
// control buses: [group in-gain, group->delay, group->verb, group->shimmer]
~groupCtl = (
	drums: Bus.control(s, 4),
	bass:  Bus.control(s, 4),
	music: Bus.control(s, 4),
	fx:    Bus.control(s, 4),
);
// aux return controls: [return level, feedback, tone, duck amount]
~auxCtl = (
	delay:   Bus.control(s, 4),
	verb:    Bus.control(s, 4),
	shimmer: Bus.control(s, 4),
);

// defaults: drums loud and dry, bass dry, music sent to both time-based effects
~groupCtl.drums.set(1.0, 0.06, 0.05, 0.0);
~groupCtl.bass.set(1.0, 0.0, 0.0, 0.0);
~groupCtl.music.set(0.95, 0.45, 0.3, 0.25);
~groupCtl.fx.set(0.9, 0.5, 0.55, 0.4);
~auxCtl.delay.set(0.55, 0.55, 2600, 0.5);
~auxCtl.verb.set(0.5, 0.0, 9000, 0.35);
~auxCtl.shimmer.set(0.45, 0.6, 4200, 0.2);

// ---------------------------------------------------------------- group strip
// one insert per group: gain, aux sends, gentle compression, then out to master
[1, 2].do { |ch|
	SynthDef("phononGroup" ++ ch, { |in, out, ctl,
		delayBus, verbBus, shimmerBus, hpf = 30|
		var sig = In.ar(in, ch);
		var gain  = In.kr(ctl + 0, 1);
		var sDel  = In.kr(ctl + 1, 1);
		var sVerb = In.kr(ctl + 2, 1);
		var sShim = In.kr(ctl + 3, 1);
		sig = HPF.ar(sig, hpf);
		sig = Compander.ar(sig, sig, thresh: 0.4, slopeBelow: 1,
			slopeAbove: 0.7, clampTime: 0.01, relaxTime: 0.25);
		sig = sig * gain;
		Out.ar(delayBus, sig * sDel);
		Out.ar(verbBus, sig * sVerb);
		Out.ar(shimmerBus, sig * sShim);
		Out.ar(out, sig);
	}).add;

	// ------------------------------------------------------------ aux returns
	// delay: dub-style, filtered feedback so repeats darken and never accumulate
	SynthDef("phononAuxDelay" ++ ch, { |in, out, ctl, duckBus|
		var sig = In.ar(in, ch);
		var lvl  = In.kr(ctl + 0, 1);
		var fb   = In.kr(ctl + 1, 1);
		var tone = In.kr(ctl + 2, 1);
		var duck = In.kr(ctl + 3, 1);
		var fbSig = LocalIn.ar(ch);
		var mixed = sig + (fbSig * fb);
		var tap = DelayC.ar(HPF.ar(mixed, 220), 2.5, 0.375)
			+ DelayC.ar(HPF.ar(mixed, 260), 2.5, 0.5625) * 0.6;
		tap = LPF.ar(tap, tone);
		tap = (tap * 1.6).tanh * 0.6;
		LocalOut.ar(tap * fb.clip(0, 0.92));
		tap = tap * (1 - (duck * Amplitude.kr(In.ar(duckBus, ch).asArray.sum, 0.004, 0.12).clip(0, 1)));
		Out.ar(out, tap * lvl);
	}).add;

	// verb: JPverb with the low band decaying fast (the anti-mush setting)
	SynthDef("phononAuxVerb" ++ ch, { |in, out, ctl, duckBus|
		var sig = In.ar(in, ch);
		var lvl  = In.kr(ctl + 0, 1);
		var fb   = In.kr(ctl + 1, 1);
		var tone = In.kr(ctl + 2, 1);
		var duck = In.kr(ctl + 3, 1);
		var wet = JPverb.ar(In.ar(in, ch).asArray.sum * 0.5,
			t60: 8, damp: 0.6, size: 1.0, earlyDiff: 0.85,
			modDepth: 0.3, modFreq: 0.4, low: 0.3, mid: 1.0, high: 0.9,
			lowcut: 400, highcut: 7000);
		wet = LPF.ar(wet, tone);
		wet = wet * (1 - (duck * Amplitude.kr(In.ar(duckBus, ch).asArray.sum, 0.004, 0.12).clip(0, 1)));
		Out.ar(out, wet * lvl * 0.8);
	}).add;

	// shimmer: Greyhole (modulated delay-verb) with feedback — the evolving tail
	SynthDef("phononAuxShimmer" ++ ch, { |in, out, ctl, duckBus|
		var sig = In.ar(in, ch);
		var lvl  = In.kr(ctl + 0, 1);
		var fb   = In.kr(ctl + 1, 1);
		var tone = In.kr(ctl + 2, 1);
		var duck = In.kr(ctl + 3, 1);
		var wet = Greyhole.ar(In.ar(in, ch).asArray.sum * 0.4,
			delayTime: 0.6, damp: 0.5, size: 1.6, diff: 0.7,
			feedback: 0.7, modDepth: 0.4, modFreq: 0.2);
		wet = LPF.ar(wet, tone);
		wet = wet * (1 - (duck * Amplitude.kr(In.ar(duckBus, ch).asArray.sum, 0.004, 0.12).clip(0, 1)));
		Out.ar(out, wet * lvl * 0.7);
	}).add;
};

// ---------------------------------------------------------------- instantiate
~routingNodes = [];
~startRouting = {
	var duckBus = ~dirt.orbits[0].dryBus;   // orbit 0 = drums, kick is the trigger
	~groupCtl.keysValuesDo { |name, ctl|
		var grp = ~groups[name];
		~routingNodes = ~routingNodes.add(
			Synth(\phononGroup2, [\in, grp.index, \out, ~masterBus.index, \ctl, ctl.index,
				\delayBus, ~aux.delay.index, \verbBus, ~aux.verb.index,
				\shimmerBus, ~aux.shimmer.index], addAction: \addToTail));
	};
	~routingNodes = ~routingNodes.add(
		Synth(\phononAuxDelay2, [\in, ~aux.delay.index, \out, ~masterBus.index,
			\ctl, ~auxCtl.delay.index, \duckBus, duckBus.index], addAction: \addToTail));
	~routingNodes = ~routingNodes.add(
		Synth(\phononAuxVerb2, [\in, ~aux.verb.index, \out, ~masterBus.index,
			\ctl, ~auxCtl.verb.index, \duckBus, duckBus.index], addAction: \addToTail));
	~routingNodes = ~routingNodes.add(
		Synth(\phononAuxShimmer2, [\in, ~aux.shimmer.index, \out, ~masterBus.index,
			\ctl, ~auxCtl.shimmer.index, \duckBus, duckBus.index], addAction: \addToTail));
};

// ---------------------------------------------------------------- API
// orbit -> group (explicit map: `this` inside a Function is NOT the enclosing
// Event, which is what made the first version hang the boot)
~orbitGroupMap = (0: \drums, 1: \bass, 2: \music, 3: \music, 4: \fx);

~route = (
	assign: ~orbitGroupMap,
	orbit: { |index, group = \music|
		var bus = ~groups[group];
		if(bus.isNil) {
			("no such group: " ++ group).warn;
		} {
			~orbitGroupMap = ~orbitGroupMap.put(index, group);
			if(index < ~dirt.orbits.size) { ~dirt.orbits[index].outBus = bus };
			("orbit % -> % group".format(index, group)).postln;
		};
	},
	send: { |group, aux, level = 0.3|
		var ctl = ~groupCtl[group];
		var slot = (delay: 1, verb: 2, shimmer: 3)[aux];
		if(ctl.isNil or: { slot.isNil }) { "bad group/aux".warn; ^this };
		ctl.setAt(slot, level);
		("% -> % send = %".format(group, aux, level)).postln;
	},
	level: { |group, gain| ~groupCtl[group].setAt(0, gain) },
	ret: { |aux, level| ~auxCtl[aux].setAt(0, level) },
	levels: {
		~groupCtl.keysValuesDo { |name, ctl|
			("%  in=% send(d/v/s)=%/%/%".format(name,
				ctl.getSynchronous(0).round(0.01),
				ctl.getSynchronous(1).round(0.01),
				ctl.getSynchronous(2).round(0.01),
				ctl.getSynchronous(3).round(0.01))).postln;
		};
		~auxCtl.keysValuesDo { |name, ctl|
			("aux %  level=% fb=% tone=%".format(name,
				ctl.getSynchronous(0).round(0.01), ctl.getSynchronous(1).round(0.01),
				ctl.getSynchronous(2).round(1))).postln;
		};
	},
);

"routing: groups %, aux %".format(~groups.keys.asArray, ~aux.keys.asArray).postln;
)
