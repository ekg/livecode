// hoRhodes: warm, self-freeing SuperDirt adaptation of SCLOrkSynths
// keyboards/FMRhodes1.scd (Nathan Ho's native SuperCollider Rhodey port;
// SCLOrk adaptation by Josh Mitchell and Bruno Ruviaro, July 2019).
//
// The source uses four sine oscillators and percussion envelopes plus an
// ASR gate. For Tidal, replace the unreleased gate with one bounded envelope,
// omit its bright 30x-frequency partial, and mix a fundamental sine so stacked
// chord notes stay warm. No detuned oscillators or inharmonic pulse partials.
(
SynthDef(\hoRhodes, { |out = 0, freq = 440, sustain = 1, pan = 0,
    amp = 0.36, attack = 0.012, release = 0.5, cutoff = 3100,
    waveMix = 0.12|
    var dur = (sustain * 0.35 + release).clip(0.3, 2.8);
    var env = EnvGen.kr(Env.perc(attack.clip(0.002, 0.12), dur, 1, -3), doneAction: 2);
    var tineEnv = EnvGen.kr(Env.perc(0.003, (dur * 0.45).max(0.12)));
    var mod = SinOsc.ar(freq * 1.99) * waveMix.clip(0, 0.4) * 1.2 * tineEnv;
    var fundamental = SinOsc.ar(freq);
    var octave = SinOsc.ar(freq * 2);
    var tine = SinOsc.ar(freq * 2, mod);
    var sig = (fundamental * 0.74) + (octave * 0.16) + (tine * 0.14 * tineEnv);
    sig = LPF.ar(sig, cutoff.clip(500, 9000)) * env * amp * 0.58;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;
~dirt.soundLibrary.addSynth(\hoRhodes,
    (instrument: \hoRhodes, amp: 0.36, cutoff: 3100, release: 0.5));
"sc/horhodes.scd loaded: warm bounded SCLOrk FM Rhodes adaptation".postln;
)
