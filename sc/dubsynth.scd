// dubsynth: dubchord's voice, made flexible.
//
// Identical architecture to `dubchord` (sc/dub_fx.scd) - detuned saw stack [0.5, 1-d, 1, 1+d]
// through RLPF with a percussive filter envelope, tanh drive, plus a sine sub - but every
// musical character is now a controllable parameter:
//
//   waveMix  how much of the fundamental-frequency saw pair is audible (0 = pure sine sub
//            tone, 1 = full saw stack). This is the key knob: low values are warm and round
//            (safe to stack into chords), high values are bright and aggressive (use single
//            notes). The 0.5x sub-octave saw is ALWAYS present at `subMix` level.
//   detune   detune of the +/- pair. dubchord default 0.14; go lower (0.04-0.08) when
//            stacking chords so instances blend instead of beating against each other.
//   spread   stereo width of the detuned pair (passed to Splay when n > 1).
//   cutoff / fenv / res / drive / subTone / attack   as in dubchord.
//   NOTE: the sine-sub level is `subTone`, not `sub` - `sub` is a SuperDirt unit
//   control and arrives as nil, which crashes the SynthDef build.
//
// Same safety rules: bounded sustain-driven envelope, doneAction 2, orbit `out`, DirtPan.
(
SynthDef(\dubsynth, { |out = 0, freq = 220, sustain = 1, pan = 0, amp = 0.5,
    detune = 0.14, waveMix = 0.5, subMix = 0.35, subTone = 0.25, spread = 0.7,
    cutoff = 700, fenv = 3.2, res = 0.35, drive = 0.35,
    attack = 0.004, speed = 1, accelerate = 0,
    keyShift = 0, vib = 0, vibRate = 5.2, trem = 0, tremRate = 4.4|

    var n    = ~dirt.numChannels;
    // +/-`vib` semitones at `vibRate` Hz, tremolo depth `trem` at `tremRate` Hz.
    var f = freq * (2 ** (keyShift.clip(-24, 24) / 12)) * (1 + (SinOsc.kr(vibRate.clip(0.05, 12)) * vib.clip(0, 2) * 0.0595));
    var tremolo = 1 - (trem.clip(0, 1) * (1 - SinOsc.kr(tremRate.clip(0.01, 20))) * 0.5);
    var env  = EnvGen.kr(Env.linen(attack, sustain * 0.65, sustain * 2.4, 1, -3), doneAction: 2);
    var fmod = EnvGen.kr(Env.perc(0.002, 0.28), levelScale: fenv);
    var base = f * DirtFreqScale.kr(speed, accelerate, sustain);
    var saws = Saw.ar(base * [0.5, 1 - detune, 1, 1 + detune]) * [subMix, waveMix * 0.7, waveMix, waveMix * 0.7];
    var subO = SinOsc.ar(base * 0.5) * subTone;
    var sig  = (saws.sum + subO);
    sig = RLPF.ar(sig, (cutoff * (1 + fmod)).clip(40, 17000), res.clip(0.05, 0.95));
    sig = (sig * (1 + (drive * 4))).tanh * 0.4;
    sig = sig * env * amp * tremolo;
    sig = if(n == 1) { sig.asArray.sum } { Splay.ar(sig.asArray, spread) };
    Out.ar(out, DirtPan.ar(sig, n, pan));
}).add;

~dirt.soundLibrary.addSynth(\dubsynth, (instrument: \dubsynth, amp: 0.5, cutoff: 700));
"sc/dubsynth.scd loaded: dubsynth = dubchord with waveMix/subMix/spread controls".postln;
)
