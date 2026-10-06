// sweetChords: a warm FM/additive chord voice for SuperDirt orbits.
//
// Deliberately NOT copied from SCLOrkSynths: those use Env.asr(gate: gate) with gate
// defaulting to 1, which under SuperDirt never reaches 0 and leaks a synth forever.
// This takes SuperDirt's `sustain`, frees itself with doneAction: 2, writes to the
// orbit's `out`, and pans with DirtPan. No hardwired hardware output.
//
// NOTE: the FM index parameter is called `fmIndex`, NOT `index` - `index` is a Tidal
// function and `# index 1.1` fails to compile as a control setting.
(
SynthDef(\sweetChords, { |out = 0, freq = 220, sustain = 1, pan = 0, amp = 0.63,
    cutoff = 5200, detune = 0.008, attack = 0.012, release = 1.6, ratio = 2,
    fmIndex = 1.1, drive = 1.4, sub = 0.4, width = 0.7,
    keyShift = 0, vib = 0, vibRate = 5.2, trem = 0, tremRate = 4.4|
    // +/-`vib` semitones at `vibRate` Hz, tremolo depth `trem` at `tremRate` Hz.
    var f = freq * (2 ** (keyShift.clip(-24, 24) / 12)) * (1 + (SinOsc.kr(vibRate.clip(0.05, 12)) * vib.clip(0, 2) * 0.0595));
    var tremolo = 1 - (trem.clip(0, 1) * (1 - SinOsc.kr(tremRate.clip(0.01, 20))) * 0.5);
    var env = EnvGen.kr(Env.linen(attack, sustain * 0.75, release, 1, -3), doneAction: 2);
    var mod = SinOsc.ar(f * ratio, 0, f * fmIndex * env);
    var car = SinOsc.ar(f + mod, 0, 1);
    var v2  = SinOsc.ar(f * (1 + detune), 0, 0.7);
    var v3  = SinOsc.ar(f * (1 - detune), 0, 0.7);
    var low = SinOsc.ar(f * 0.5, 0, sub);
    var sig = (car + v2 + v3 + low) * drive;
    sig = LPF.ar(sig, cutoff);
    sig = sig * env * amp * tremolo;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;

~dirt.soundLibrary.addSynth(\sweetChords, (instrument: \sweetChords, release: 1.6, amp: 0.63));
"sc/chords.scd loaded: sweetChords registered (param is fmIndex, not index)".postln;
)
