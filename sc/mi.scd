// miLead: Mutable Instruments Plaits as a SuperDirt-orbit lead voice.
//
// This is the MI integration that was installed but never wired up. MiPlaits takes
// `pitch` as a MIDI note number (not Hz), which is what freq.cpsmidi converts.
//
// engine 0-23: 0 virtual_analog, 1 waveshaping, 2 fm, 3 grain, 4 additive, 5 wavetable,
// 6 chord, 7 speech, 8 swarm, 9 noise, 10 particle, 11 string, 12 modal, 13 bass_drum,
// 14 snare, 15 hi_hat, 16 virtual_analog_vcf, 17 phase_distortion, 18-20 6-op banks,
// 21 wave_terrain, 22 string_machine, 23 chiptune
//
// Same safety rules as sweetChords: bounded sustain-driven envelope, doneAction 2,
// writes to the orbit's `out`, pans with DirtPan. No gate that can leak.
(
SynthDef(\miLead, { |out = 0, freq = 220, sustain = 1, pan = 0, amp = 0.5,
    engine = 11, harm = 0.4, timbre = 0.5, morph = 0.5, cutoff = 9000,
    attack = 0.006, release = 0.4, level = 0.7, lpgColour = 0.5|

    var env = EnvGen.kr(Env.linen(attack, sustain * 0.85, release, 1, -3), doneAction: 2);
    var sig = MiPlaits.ar(freq.cpsmidi, engine, harm, timbre, morph, 0, level,
        0, 0, 0, 0.5, lpgColour);
    sig = LPF.ar(sig, cutoff) * env * amp;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;

~dirt.soundLibrary.addSynth(\miLead, (instrument: \miLead, release: 0.4, amp: 0.5));
"sc/mi.scd loaded: miLead (MiPlaits engine 11 = string) registered".postln;
)
