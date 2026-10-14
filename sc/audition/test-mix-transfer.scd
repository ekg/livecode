// Synthetic intermodulation regression on the isolated audition server only.
(
if(s.addr.port != 57111) { Error("test-mix-transfer requires audition port 57111").throw };
Routine({
    var path = "/home/erik/livecode/recordings/diagnostics-174/two-tone-transfer.wav";
    var buffer;
    SynthDef(\diagMixTransfer, { |bufnum = 0|
        var amp = Select.kr(Line.kr(0, 4, 8).floor.clip(0, 3), [0.03, 0.1, 0.3, 0.6]);
        var input = (SinOsc.ar(43) + (SinOsc.ar(86) * 0.12)) * amp + (SinOsc.ar(997) * 0.02);
        // Deliberately retain the faulty SC expression in the reference branch.
        var oldScene = (input * (1 + 0.13 * 3)).tanh / (1 + 0.13) * 1.45;
        var fixedScene = (input * (1 + (0.13 * 3))).tanh / (1 + 0.13) * 1.45;
        var oldMaster = (((oldScene * 1.36).tanh / 1.12 * 0.9) / 0.75).tanh * 0.75;
        var fixedMaster = (((fixedScene * 1.36).tanh / 1.12 * 0.9) / 0.75).tanh * 0.75;
        var zeroBug = (input * (1 + 0 * 3)).tanh;
        var zeroFixed = (input * (1 + (0 * 3))).tanh;
        DiskOut.ar(bufnum, [input, oldScene, fixedScene, oldMaster, fixedMaster, zeroBug, zeroFixed, input]);
        FreeSelf.kr(Line.kr(0, 1, 8.1) >= 1);
    }).add;
    s.sync;
    buffer = Buffer.alloc(s, 65536, 8); s.sync;
    buffer.write(path, "wav", "float", 0, 0, true); s.sync;
    Synth.tail(0, \diagMixTransfer, [\bufnum, buffer.bufnum]);
    8.5.wait;
    buffer.close; buffer.free;
    File.use("/home/erik/livecode/sc/audition/run/two-tone.done", "w", { |f| f.write("done") });
    "TWO-TONE TRANSFER DONE".postln;
}).play(SystemClock);
)
