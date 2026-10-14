// Audition-only simultaneous taps: no change to any live graph or bus route.
(
if(s.addr.port != 57111) { Error("diagnose-174 requires isolated audition port 57111").throw };
Routine({
    var bus, file = "/home/erik/livecode/recordings/diagnostics-174/nonlinear-taps.wav";
    if(~piSceneAPI.notNil) { ~piSceneAPI[\dispose].value; 1.wait; s.sync };
    this.executeFile("/home/erik/pi-tidal/sc/scenes.scd");
    ~piSceneAPI[\install].value("diag-install", 4, 6);
    1.wait; s.sync;
    if(~piSceneManager[\installed].not) { Error("scene install failed").throw };
    bus = ~piSceneManager[\buses][0].index;
    ~masterCtlBus.setn([0.9, 0.45, 0.06, 11000, 0.22, 48, 0.30, 1.0]);
    Ndef(\dubMaster).set(\dWet, 0, \mKnee, 0.75, \mCeil, 0.85);
    // Fixed representative scene controls; shared source for all comparisons.
    ~piSceneManager[\initial0].setn([4000, 0.13, 0.04, 1.45]);
    SynthDef(\diag174Taps, { |bufnum = 0|
        var raw = In.ar(bus, 2);
        var sceneActual = In.ar(~masterBus.index, 2);
        var finalActual = In.ar(0, 2);
        var filtered = LPF.ar(raw, 4000);
        var sceneDryLinear = filtered * 1.45;
        var masterDry = HPF.ar(sceneActual, 48);
        var compressed = Compander.ar(masterDry, masterDry, 0.30, 1, 0.45, 0.008, 0.22);
        var tape = (compressed * 1.36).tanh / 1.12;
        var preKnee = LPF.ar(tape, 11000) * 0.9;
        var noMasterShape = LPF.ar(compressed, 11000) * 0.9;
        var noSceneShape = HPF.ar(sceneDryLinear, 48);
        var fullyLinear;
        noSceneShape = Compander.ar(noSceneShape, noSceneShape, 0.30, 1, 0.45, 0.008, 0.22);
        fullyLinear = LPF.ar(noSceneShape, 11000) * 0.9;
        // Channels: raw orbit sum, actual scene, actual master, before knee,
        // master shaping bypass, scene+master shaping bypass (unlimited).
        DiskOut.ar(bufnum, raw ++ sceneActual ++ finalActual ++ preKnee
            ++ noMasterShape ++ fullyLinear);
    }).add;
    s.sync;
    ~diag174Buffer = Buffer.alloc(s, 65536, 12);
    s.sync;
    ~diag174Buffer.write(file, "wav", "float", 0, 0, true);
    s.sync;
    ~diag174Recorder = Synth.tail(0, \diag174Taps, [\bufnum, ~diag174Buffer.bufnum]);
    File.use("/home/erik/livecode/sc/audition/run/diag174.ready", "w", { |f| f.write("ready") });
    "DIAG174 RECORDING READY".postln;
}).play(SystemClock);
)
