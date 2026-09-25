/*
demo_synth.scd — a worked example of the whole loop:

    1. define an instrument in SuperCollider
    2. sequence it from Tidal                (livecode/54.tidal)
    3. tweak it live from SuperCollider      (~demo.tweak(...))
    4. save that tweak into the state file   (~sc.save)

Two levels of modulation are shown on purpose:

  * per event, from Tidal:   d7 $ s "demoVoice" # cutoff 900 # drive 0.4
    (the arguments of the SynthDef ARE the modulation surface — no bridge needed)
  * globally, from SC:       ~demo.tweak(cutoff: 600)
    (writes a control bus that every voice reads on top of its own value, so a
     change affects notes already sounding and everything that follows)

That second level is the thing that "needs a bridge" in general. Here it is done
the simple way: one control bus created at boot, with its index baked into the
SynthDef, read continuously.
*/
(
var n = 2;

// ---------------------------------------------------------------- the control bus
// [0] cutoff offset  [1] resonance  [2] drive offset
~demoBus = Bus.control(s, 3);
~demoBus.set(0, 0.0, 0.0);           // offsets: zero means "no global change"

// ---------------------------------------------------------------- the instrument
[1, 2].do { |ch|
	SynthDef("demoVoice" ++ ch, { |out, freq = 220, sustain = 1, pan = 0,
		cutoff = 1200, res = 0.4, drive = 0.2, detune = 0.008, fmix = 0.3,
		amp = 0.5, speed = 1, accelerate = 0, wavemix = 0.5|

		var base = freq * DirtFreqScale.kr(speed, accelerate, sustain);
		var env = EnvGen.kr(Env.linen(0.005, sustain * 0.6, sustain * 2, 1, -4),
			doneAction: 2);
		var fenv = EnvGen.kr(Env.perc(0.002, 0.28), levelScale: 2.2);

		// global offsets read live from the control bus
		var cutOff = In.kr(~demoBus.index + 0, 1);
		var resBus = In.kr(~demoBus.index + 1, 1);
		var drvAdd = In.kr(~demoBus.index + 2, 1);

		var osc = SinOsc.ar(base)
			+ (SinOsc.ar(base * (2 + detune)) * fmix)
			+ (LFTri.ar(base * 1.5) * (wavemix * 0.3));
		var sig = RLPF.ar(osc,
			((cutoff + cutOff) * (1 + fenv)).clip(60, 16000),
			(res + resBus).clip(0.05, 0.95));
		sig = (sig * (1 + ((drive + drvAdd) * 5))).tanh * 0.4;
		sig = sig * env * amp;
		sig = if(ch == 1) { sig } { Splay.ar([sig, DelayC.ar(sig, 0.05, 0.011)], 0.6) };
		Out.ar(out, DirtPan.ar(sig, ch, pan));
	}).add;
};

// ---------------------------------------------------------------- live tweak API
~demo = (
	// values are OFFSETS applied on top of what each event asks for
	cutoff: { |hz = 0| ~demoBus.setAt(0, hz); "demo cutoff offset % Hz".format(hz).postln },
	res: { |q = 0| ~demoBus.setAt(1, q); "demo resonance offset %".format(q).postln },
	drive: { |d = 0| ~demoBus.setAt(2, d); "demo drive offset %".format(d).postln },
	state: {
		"demo offsets: cutoff +% Hz  res +%  drive +%".format(
			~demoBus.getSynchronous(0), ~demoBus.getSynchronous(1),
			~demoBus.getSynchronous(2)).postln;
	},
);

// ---------------------------------------------------------------- include in the surface
// so these appear in ~sc.state and survive ~sc.save / ~sc.load
if(~scSlots.notNil) {
	~scSlots.put(\demoCutoff, [
		{ ~demoBus.getSynchronous(0) }, { |v| ~demoBus.setAt(0, v) }]);
	~scSlots.put(\demoRes, [
		{ ~demoBus.getSynchronous(1) }, { |v| ~demoBus.setAt(1, v) }]);
	~scSlots.put(\demoDrive, [
		{ ~demoBus.getSynchronous(2) }, { |v| ~demoBus.setAt(2, v) }]);
};

"demo_synth: instrument 'demoVoice' defined; ~demo.cutoff/res/drive/state to tweak".postln;
~scLoadedDemo = true;  // sentinel: init.scd verifies this to catch a silent parse no-op
)
