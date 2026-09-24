/*
selftest.scd — boot-time verification that the DSP layer actually makes sound.

Silence is the hardest failure to debug in a livecoding stack: the pattern is
valid, sclang reports no error, and nothing comes out. So instead of assuming a
SynthDef works, this plays each instrument into a private bus, meters it, and
writes the measured peak to sc/boot.log. A broken graph then shows up as 0.0
next to a working one's ~-12 dB, which is unambiguous.

Notes learned the hard way:
  * pass bus INDEXES to Synth args, not Bus objects — SuperDirt does the same,
    and a Bus object here yields a bogus bus index and perfect silence.
  * read the meter back through a control bus with Bus.get (async), rather than
    SendReply + OSCdef, so there is no reply-address dependency.
*/
(
~selftest = { |log, testBus, testCtl|
	var names = [\dubchord, \dubsub, \tapestab, \superpiano];
	var results = [];

	SynthDef(\selftestMeter, { |in, ctl|
		var sig = In.ar(in, 2);
		Out.kr(ctl, Amplitude.kr(sig.sum, 0.005, 0.08));
	}).add;
	s.sync;

	names.do { |nm|
		var meter, peak = 0.0;
		meter = Synth(\selftestMeter,
			[\in, testBus.index, \ctl, testCtl.index], addAction: \addAfter);
		s.sync;
		try {
			Synth(nm, [\out, testBus.index, \freq, 220, \amp, 0.5, \sustain, 0.5]);
		} { |err| log.("     " ++ nm ++ " could not be started: " ++ err.errorString) };
		s.sync;
		// sample the meter a few times across the note's life and keep the max
		6.do {
			testCtl.get { |v| peak = max(peak, v ? 0) };
			0.12.wait;
		};
		meter.free;
		results = results.add(nm.asString ++ "=" ++ peak.round(0.0001));
	};

	log.("     selftest peaks (0.0 = silent): " ++ results.join("  "));
}
)
