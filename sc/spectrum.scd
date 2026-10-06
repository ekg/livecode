/* sc/spectrum.scd — BAND-POWER METERING.
   Purpose: answer "who owns the low end?" with numbers instead of ears, because
   a broadband RMS meter cannot see that a kick is 80% of the energy — it only
   sees that the total is loud. The recurring failure in this project is a kick
   dominating the sub/bass bands — and because orbit 0 is the master's sidechain
   detector, a loud kick also ducks everything else.

   One \piBandMeter per source — the master bus plus every live scene channel
   bus — publishes six band amplitudes and a broadband RMS to a control bus.
   ~spectrumStart / ~spectrumReport read them back as share-of-total percentages
   and append the table to sc/spectrum.log (readable outside sclang, since the
   getn callback is asynchronous and is not returned to the caller).

   Deliberately approximate: overlapping BPF bands, not an FFT. This is a MIXING
   instrument — good enough to see proportions, not a measurement lab.
   Metering only: it never writes audio or touches routing.
*/
(
var bands, labels, ranges, db, pad, write;

// [centre Hz, rq]; bandwidth = centre/rq, so neighbours overlap slightly
bands = [[44, 1.4], [95, 1.4], [245, 1.4], [775, 1.4], [2740, 1.4], [8900, 1.4]];
labels = ["sub", "bass", "lowmid", "mid", "highmid", "top"];
ranges = ["30-60", "60-150", "150-400", "400-1.5k", "1.5k-5k", "5k-16k"];
db = { |amp| (20 * log10(amp + 1e-9)).round(0.1) };
pad = { |s, width| (s.asString ++ "                    ").copyRange(0, width - 1) };

~spectrumLog = Platform.userHomeDir ++ "/livecode/sc/spectrum.log";
~spectrumWarnCeilingUse = 0.7;            // within ~3 dB of the limiter ceiling
~spectrumStride = 7;                      // six bands + broadband rms

write = { |text|
    var f = File(~spectrumLog, "a");
    if(f.notNil) { f.write(text ++ "\n"); f.close };
    text.postln;
};

SynthDef(\piBandMeter, { |in = 0, out = 0, rmsOut = 0|
    // Fixed 2-channel input: SuperDirt runs stereo here, and a channel count
    // passed as a SynthDef argument is a UGen at build time, not a number.
    var sig = In.ar(in, 2);
    var mono = sig.asArray.sum * 0.5;
    // Amplitude.kr is an RMS-ish follower. Window length matters: with a short window
    // a single report lands wherever it lands relative to the kick and the same track
    // reads 13% sub in one snapshot and 72% in the next (measured). Balance needs a
    // window longer than a beat, so this is deliberately slow (~2.5s release).
    bands.do { |pair, i|
        Out.kr(out + i, Amplitude.kr(BPF.ar(mono, pair[0], pair[1]), 0.25, 2.5));
    };
    Out.kr(rmsOut, Amplitude.kr(mono, 0.25, 2.5));
}).add;

~spectrumBands = bands;
~spectrumLabels = labels;
~spectrumRanges = ranges;

// Sources: the master bus, then each rendered scene channel (if scene mode runs)
~spectrumSources = {
    var list = [["master", ~masterBus.index]];
    var manager = ~piSceneManager;
    if(manager.notNil and: { manager[\buses].notNil }) {
        manager[\buses].do { |bus, i| if(bus.notNil) { list = list.add(["ch" ++ i, bus.index]) } };
    };
    // NO per-lane / per-orbit source: in scene mode the scene runtime points each
    // orbit's outBus at its channel bus (verified: orbit0.outBus == ch0 bus), so the
    // finest granularity available is one channel. Metering orbit dryBus reads
    // silence and is misleading - do not add it back.
    list
};

~spectrumStop = {
    if(~spectrumMeters.notNil) { ~spectrumMeters.do(_.free) };
    ~spectrumMeters = nil;
};

~spectrumStart = {
    var sources = ~spectrumSources.value;
    ~spectrumStop.value;
    ~spectrumBus = Bus.control(s, sources.size * ~spectrumStride);
    ~spectrumMeters = sources.collect { |pair, i|
        Synth(\piBandMeter, [
            \in, pair[1],
            \out, ~spectrumBus.index + (i * ~spectrumStride),
            \rmsOut, ~spectrumBus.index + (i * ~spectrumStride) + 6
        ], addAction: \addToTail);
    };
    ~spectrumNames = sources.collect(_[0]);
    "spectrum: metering % source(s): %. Amplitude followers need audio blocks to
    build up, so read the report a moment later - do not start and report in the
    same instant (it reads zeros).".format(sources.size, ~spectrumNames.join(" ")).postln;
};

~spectrumReport = {
    var names = ~spectrumNames, stride = ~spectrumStride, lines;
    if(~spectrumBus.isNil or: { names.isNil }) {
        "spectrum: not started - run ~spectrumStart.value first".postln;
    } {
        // Synchronous reads via subBus: Bus:getn is async and its callback output is
        // not returned to the caller, and getSynchronous(index) ignores the index.
        var m = (0..2).collect { |i| ~meterBus.subBus(i).getSynchronous };
        lines = List.new;
        lines.add("--- spectrum report " ++ Date.getDate.stamp ++ " ---");
        lines.add("master   rms % dB   peak % dB   ceiling-use % (%)".format(
            db.(m[0]), db.(m[1]), m[2].round(0.01), (m[2] * 100).round(1)));
        if(m[2] > ~spectrumWarnCeilingUse) {
            lines.add("  ^ WARNING: within ~3 dB of the limiter ceiling - the master is being squashed; a kick is the usual cause");
        };
        names.do { |name, i|
            var b = (0..5).collect { |k| ~spectrumBus.subBus(i * stride + k).getSynchronous };
            var rms = ~spectrumBus.subBus(i * stride + 6).getSynchronous;
            var total = b.sum.max(1e-9);
            var shares = (0..5).collect { |k| (b[k] / total * 100).round(1) };
            var lowEnd = ((b[0] + b[1]) / total * 100).round(1);
            lines.add(pad.(name, 8) ++ "rms " ++ pad.(db.(rms).asString, 8)
                ++ "low-end " ++ pad.(lowEnd.asString ++ "%", 8)
                ++ "shares " ++ shares.join(" "));
        };
        lines.add("bands, in order: " ++ [labels, ranges].flop.collect({ |p| p[0] ++ " " ++ p[1] }).join(" | "));
        lines.do(write);
    };
};

// A single ~spectrumReport samples one moment. Scenes whose form gates lanes in and
// out swing a lot over a 32-64 cycle arrangement (measured on 152: sub 13% -> 72%
// at different points in the form), so balance questions need a MEAN over time.
// Writes to sc/spectrum.log because a Routine's output is not returned to the caller.
~spectrumReportAvg = { |seconds = 15, interval = 1.0|
    var names = ~spectrumNames, stride = ~spectrumStride;
    if(~spectrumBus.isNil or: { names.isNil }) {
        "spectrum: not started - run ~spectrumStart.value first".postln;
    } {
        var samples = 0, acc, rmsAcc;
        acc = Array.fill(names.size * 6, 0);
        rmsAcc = Array.fill(names.size, 0);
        Routine({
            while { samples < (seconds / interval).round.asInteger } {
                var i = 0;
                while { i < names.size } {
                    var k = 0;
                    while { k < 6 } {
                        acc[i * 6 + k] = acc[i * 6 + k] + ~spectrumBus.subBus(i * stride + k).getSynchronous;
                        k = k + 1;
                    };
                    rmsAcc[i] = rmsAcc[i] + ~spectrumBus.subBus(i * stride + 6).getSynchronous;
                    i = i + 1;
                };
                samples = samples + 1;
                interval.wait;
            };
            write.("--- AVERAGED over % s (% samples) ---".format(seconds, samples));
            names.do { |name, i|
                var b = (0..5).collect { |k| acc[i * 6 + k] / samples };
                var total = b.sum.max(1e-9);
                var shares = (0..5).collect { |k| (b[k] / total * 100).round(1) };
                write.(pad.(name, 8) ++ "rms " ++ pad.(db.(rmsAcc[i] / samples).asString, 8)
                    ++ "low-end " ++ pad.(((b[0] + b[1]) / total * 100).round(1).asString ++ "%", 8)
                    ++ "shares " ++ shares.join(" "));
            };
        }).play;
        "averaging % s of audio; the mean lands in sc/spectrum.log".format(seconds).postln;
    };
};

"sc/spectrum.scd loaded: ~spectrumStart | ~spectrumReport | ~spectrumReportAvg | ~spectrumStop".postln;
)
