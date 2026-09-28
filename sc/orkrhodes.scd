// orkRhodes: SuperDirt-safe adaptation of SCLOrkSynths/keyboards/everythingRhodes.scd.
// Original electric-piano design: Nick Collins / Mitchell Sigman (2011),
// collection adaptation: Josh Mitchell and Bruno Ruviaro (2019).
// Pulse fundamental + inharmonic bell partial through an envelope-driven
// low-pass. Added a warm sine fundamental, bounded event envelope, orbit out,
// DirtPan, and clamps for live safety. No gate / indefinitely sustained node.
(
SynthDef(\orkRhodes, { |out = 0, freq = 440, sustain = 1, pan = 0, amp = 0.4,
    cutoff = 3200, res = 0.5, attack = 0.014, release = 0.55,
    waveMix = 0.35|
    var env = EnvGen.kr(
        Env.perc(attack.clip(0.002, 0.2),
            (sustain * 0.45 + release).clip(0.3, 3.4), 1, -4), doneAction: 2);
    var pulse = Pulse.ar(freq * [1, 2.pow(33.5 / 12)], [0.23, 0.115],
        [0.8, waveMix.clip(0, 0.65)]).sum;
    var sig = BLowPass4.ar(pulse,
        (freq * 2 + cutoff.clip(400, 9000) * env).clip(70, 12000),
        res.clip(0.2, 0.85));
    sig = (sig + (SinOsc.ar(freq) * 0.36)) * env * amp * 0.34;
    Out.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add;
~dirt.soundLibrary.addSynth(\orkRhodes,
    (instrument: \orkRhodes, amp: 0.4, cutoff: 3200, release: 0.55));
"sc/orkrhodes.scd loaded: bounded SCLOrk Rhodes adaptation".postln;
)
