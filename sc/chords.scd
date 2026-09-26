// sweetChords: a warm FM/additive chord voice for SuperDirt orbits.
// Deliberately NOT copied from SCLOrkSynths: those use Env.asr(gate: gate) with gate
// defaulting to 1, which under SuperDirt never reaches 0 and leaks a synth forever.
// This one takes SuperDirt's `sustain` and frees itself with doneAction: 2, writes to
// the orbit's `out`, and pans with DirtPan. No hardwired hardware output.
(
SynthDef(\sweetChords, { |out = 0, freq = 220, sustain = 1, pan = 0, amp = 0.2,
    cutoff = 4200, detune = 0.012, attack = 0.012, release = 1.1, ratio = 2, index = 1.4, drive = 1|

    var env  = EnvGen.kr(Env.linen(attack, sustain * 0.75, release, 1, -3), doneAction: 2);
    var mod  = SinOsc.ar(freq * ratio, 0, freq * index * env);
    var car  = SinOsc.ar(freq + mod, 0, 1);
    var sub  = SinOsc.ar(freq * 0.5, 0, 0.35);
    var det  = SinOsc.ar(freq * (1 + detune), 0, 0.55);
    var sig  = (car + det + sub) * drive;
    sig = LPF.ar(sig, cutoff);
    sig = sig * env * amp;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;

~dirt.soundLibrary.addSynth(\sweetChords, (instrument: \sweetChords, release: 1.1, cutoff: 4200));
"sc/chords.scd loaded: sweetChords registered with SuperDirt".postln;
)
