/*
metrics.scd — AUDITION-ONLY measurement of the staged render.

Loaded on demand by tools/audition/job-runner.mjs into the audition sclang
(never the live stack; sc/spectrum.scd is not touched). It meters the SAME
sources lane 4 snapshots live: the master bus (`~masterBus`) plus each scene
channel bus (`~piSceneManager[\buses][i]`, created by the scene runtime). The
band definitions and the slow Amplitude.kr(0.25, 2.5) follower are copied
verbatim from sc/spectrum.scd so audition numbers are comparable to live.

Beyond the six bands + broadband rms it adds the lane-3 requirements:
  * dominantHz — band-energy-weighted spectral centroid (same notion as
    `~orbitScanReport`'s dominant; a coarse "where the energy sits" figure)
  * chroma[12]  — Chromagram (SC3plugins/SCMIR), C-based, per-frame normalised
  * dissonance  — SensoryDissonance (SC3plugins/SCMIR), 0..1
  * peak        — fast follower peak, accumulated as a running maximum
The key estimate is derived from chroma in tools/audition/job-runner.mjs
(Krumhansl-Schmuckler), not here.

Metering only: it never writes audio or touches routing.

Control-bus layout per source (stride 22):
  0..5 bands | 6 rms | 7 peak | 8 dominantHz | 9..20 chroma[12] | 21 dissonance
*/
(
var bandDefs = [[44, 1.4], [95, 1.4], [245, 1.4], [775, 1.4], [2740, 1.4], [8900, 1.4]];
var bandLabels = ["sub", "bass", "lowmid", "mid", "highmid", "top"];
var centers = bandDefs.collect(_[0]);

~auditionBandDefs = bandDefs;
~auditionBandLabels = bandLabels;
~auditionStride = 22;

SynthDef(\piAuditionMeter, { |in = 0, out = 0|
	var sig = In.ar(in, 2);
	var mono = sig.asArray.sum * 0.5;
	var amps = bandDefs.collect { |pair| Amplitude.kr(BPF.ar(mono, pair[0], pair[1]), 0.25, 2.5) };
	var total = amps.sum + 1e-9;
	var dom = (amps * centers).sum / total;
	var rms = Amplitude.kr(mono, 0.25, 2.5);
	var peak = Amplitude.kr(mono, 0.001, 0.05);
	var fft = FFT(LocalBuf(2048), mono);
	var chroma = Chromagram.kr(fft, 2048, 12, 32.703195662575, 6, 0, 0.9, 2, 0);
	var dis = SensoryDissonance.kr(fft).clip(0, 1);
	Out.kr(out, amps);                     // 6 bands
	Out.kr(out + 6, [rms, peak, dom]);     // rms, peak, dominantHz
	Out.kr(out + 9, chroma);               // 12 chroma
	Out.kr(out + 21, dis);                 // dissonance
}).add;

~auditionMeterStop = {
	if(~auditionMeterRoutine.notNil) { ~auditionMeterRoutine.stop; ~auditionMeterRoutine = nil };
	if(~auditionMeterSynths.notNil) { ~auditionMeterSynths.do(_.free); ~auditionMeterSynths = nil };
	if(~auditionMeterBus.notNil) { ~auditionMeterBus.free; ~auditionMeterBus = nil };
	~auditionMeterNames = nil;
	~auditionMeterAcc = nil;
};

// names/indices are parallel: the source bus index to meter and its label.
// Sampling starts after `settle` seconds (followers need audio blocks and the
// pattern needs to reach SuperDirt); the caller stops it via ~auditionMeterReport.
~auditionMeterStart = { |names, indices, settle = 1.5, interval = 0.25|
	var n = names.size;
	var stride = ~auditionStride;
	~auditionMeterStop.value;
	~auditionMeterBus = Bus.control(s, n * stride);
	~auditionMeterSynths = names.collect { |nm, i|
		Synth(\piAuditionMeter,
			[\in, indices[i], \out, ~auditionMeterBus.index + (i * stride)],
			addAction: \addToTail);
	};
	~auditionMeterNames = names;
	~auditionMeterIndices = indices;
	~auditionMeterSamples = 0;
	~auditionMeterAcc = (
		bands: Array.fill(n, { Array.fill(6, 0.0) }),
		rms: Array.fill(n, 0.0),
		peak: Array.fill(n, 0.0),
		dom: Array.fill(n, 0.0),
		chroma: Array.fill(n, { Array.fill(12, 0.0) }),
		dis: Array.fill(n, 0.0),
	);
	~auditionMeterRoutine = Routine({
		settle.wait;
		inf.do {
			var acc = ~auditionMeterAcc;
			n.do { |i|
				var base = i * stride;
				var b = (0..5).collect { |k| ~auditionMeterBus.subBus(base + k).getSynchronous };
				var rms = ~auditionMeterBus.subBus(base + 6).getSynchronous;
				var pk = ~auditionMeterBus.subBus(base + 7).getSynchronous;
				var dom = ~auditionMeterBus.subBus(base + 8).getSynchronous;
				var ch = (0..11).collect { |k| ~auditionMeterBus.subBus(base + 9 + k).getSynchronous };
				var ds = ~auditionMeterBus.subBus(base + 21).getSynchronous;
				(0..5).do { |k| acc[\bands][i][k] = acc[\bands][i][k] + b[k] };
				acc[\rms][i] = acc[\rms][i] + rms;
				if(pk > acc[\peak][i]) { acc[\peak][i] = pk };
				acc[\dom][i] = acc[\dom][i] + dom;
				(0..11).do { |k| acc[\chroma][i][k] = acc[\chroma][i][k] + ch[k] };
				acc[\dis][i] = acc[\dis][i] + ds;
			};
			~auditionMeterSamples = ~auditionMeterSamples + 1;
			interval.wait;
		};
	}).play(SystemClock);
	"audition meters: % source(s) %, stride %".format(n, names, stride).postln;
};

// Write mean bands/rms/dom/chroma/dissonance + peak over the sampling window to
// `path` as one JSON object. Reads the accumulators synchronously; call it after
// the render window so SystemClock has had time to accumulate samples.
~auditionMeterReport = { |path, renderSeconds = 0|
	var names = ~auditionMeterNames;
	var samples = (~auditionMeterSamples ? 0).max(1);
	var acc = ~auditionMeterAcc;
	var num = { |x, p = 6| x.round(10 ** p.neg).asString };
	var arr = { |a, p = 6| "[" ++ a.collect({ |x| num.(x, p) }).join(",") ++ "]" };
	var srcs;
	if(names.isNil or: { acc.isNil }) {
		Error("audition meters were not started").throw;
	};
	srcs = (0..(names.size - 1)).collect { |i|
		"{ \"name\": " ++ names[i].asCompileString
			++ ", \"rms\": " ++ num.(acc[\rms][i] / samples)
			++ ", \"peak\": " ++ num.(acc[\peak][i])
			++ ", \"dominantHz\": " ++ num.(acc[\dom][i] / samples)
			++ ", \"bands\": " ++ arr.(acc[\bands][i].collect { |x| x / samples })
			++ ", \"chroma\": " ++ arr.(acc[\chroma][i].collect { |x| x / samples })
			++ ", \"dissonance\": " ++ num.(acc[\dis][i] / samples) ++ " }";
	};
	File.use(path, "w", { |f|
		f.write("{ \"ok\": true, \"error\": null, \"samples\": " ++ ~auditionMeterSamples
			++ ", \"renderSeconds\": " ++ num.(renderSeconds, 3)
			++ ", \"sources\": [" ++ srcs.join(",") ++ "] }");
	});
};

"sc/audition/metrics.scd loaded: ~auditionMeterStart | ~auditionMeterReport | ~auditionMeterStop".postln;
)
