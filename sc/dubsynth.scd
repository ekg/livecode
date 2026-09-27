// dubsynth: a voice designed to be stacked into chords.
//
// Why this exists: playing chord tokens like [g3,b3,d4] on `dubchord` spawns one synth
// per note, and each of those is already a detuned chord-ish voice - so the instances
// beat against each other and it sounds thin/phasey. This voice is instead a pair of
// softly detuned saws plus a sub per note, so stacking three of them blends into a real
// chord instead of fighting itself. One synth per note is then the CORRECT way to use it.
//
// Same safety rules as sweetChords / miLead: bounded sustain-driven envelope,
// doneAction 2, writes to the orbit's `out`, pans with DirtPan.
(
SynthDef(\dubsynth, { |out = 0, freq = 220, sustain = 1, pan = 0, amp = 0.5,
    detune = 0.06, cutoff = 2200, fenv = 2.4, res = 0.3, drive = 0.2,
    sub = 0.25, spread = 0.7, attack = 0.06, speed = 1, accelerate = 0|

    var env = EnvGen.kr(Env.linen(attack, sustain * 0.7, sustain * 1.6, 1, -3), doneAction: 2);
    var f   = freq * DirtFreqScale.kr(speed, accelerate, sustain);
    var fmod = EnvGen.kr(Env.perc(0.004, 0.5), levelScale: fenv);
    var a   = Saw.ar(f * (1 - detune));
    var b   = Saw.ar(f * (1 + detune));
    var c   = SinOsc.ar(f * 0.5) * sub;
    var sig = RLPF.ar((a + b + c), cutoff * (1 + fmod), res);
    sig = (sig * (1 + (drive * 3))).tanh;
    sig = sig * env * amp;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;

~dirt.soundLibrary.addSynth(\dubsynth, (instrument: \dubsynth, attack: 0.06, amp: 0.5));
"sc/dubsynth.scd loaded: dubsynth registered (chord-stacking voice)".postln;
)
