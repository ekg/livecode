// mixservo.scd — automatic GROUP BALANCE for the mixing layer.
//
// WHY: the master chain (dub_master.scd) glues and limits the SUM, but nothing
// balances layers RELATIVE to each other, and SuperDirt does not normalize
// sample loudness - so a mars one-shot, dubsub and the p70 kit all arrive at
// different levels and every blend has to be hand-set. That hand-setting was
// a seesaw (bass too strong -> drums quiet -> chords too strong -> bass gone).
//
// WHAT: ~mixServoStart meters the four group buses (drums/bass/music/fx) and
// nudges each group's gain toward a target RMS RATIO measured against drums:
//   drums 1.0  bass 0.72  music 0.85  fx 0.6
// Nudge step is clamped (max 15% per adjustment) with a 12% deadband, so it
// converges instead of oscillating. It runs forever; ~mixServoStop stops it.
// Targets adjustable at runtime: ~servoTarget[\bass] = 0.8; etc.
//
// CAVEATS: it balances GROUPS, not streams within a group (per-stream gains
// still matter), and it measures RMS over ~4 s windows - it evens out the
// balance of sections, it does not chase instantaneous dynamics.

~servoStop = true;

~mixServoStart = {
	var names = [\drums, \bass, \music, \fx];
	~servoState = ~servoState ? (drums: 1.3, bass: 1.15, music: 1.3, fx: 0.9);
	~servoTarget = ~servoTarget ? (drums: 1.0, bass: 0.72, music: 0.85, fx: 0.6);
	~servoStop = false;
	Routine {
		var buses = names.collect { |g| var x = ~groups[g]; (x.try { |xx| xx[\bus] } ?? { x }) };
		var idxs = buses.collect { |b| (b.try { |x| x.index }) ? -1 };
		var sums, n, ratios, cur, tgt, err, step;
		SynthDef(\gprobe, { |bus = 0, rid = 0|
			SendReply.kr(Impulse.kr(2), '/gprobe', Amplitude.kr(InFeedback.ar(bus, 2)), rid)
		}).add;
		s.sync;
		names.do { |nm, k|
			if(idxs[k] >= 0) { Synth.head(s.defaultGroup, \gprobe, [bus: idxs[k], rid: k]) }
		};
		while { ~servoStop.not } {
			sums = [0, 0, 0, 0]; n = [0, 0, 0, 0];
			OSCdef(\gprobeR, { |m|
				var rid = m[2].asInteger;
				if(rid < 4) { sums[rid] = sums[rid] + m[3].max(m[4]); n[rid] = n[rid] + 1 };
			}, '/gprobe');
			4.wait;
			OSCdef(\gprobeR).free;
			ratios = names.collect { |nm, k|
				if(n[k] > 0 and: { n[0] > 0 }) { (sums[k] / n[k]) / (sums[0] / n[0]).max(0.0001) } { -1 }
			};
			names.do { |nm, k|
				if(ratios[k] >= 0) {
					cur = ~servoState[nm]; tgt = ~servoTarget[nm];
					err = ratios[k] - tgt;
					if(err.abs > 0.12) {
						step = (err * 0.25).clip(-0.15, 0.15);
						cur = (cur / (1 + step)).clip(0.3, 3);
						~servoState[nm] = cur;
						~groupCtl[nm].set(cur, 0, 0, 0);
					};
				};
			};
			["servo", names, ratios.collect(_.round(0.01))].postln;
		};
	}.play;
	"mix servo running".postln;
};

"sc/mixservo.scd loaded: ~mixServoStart / ~servoStop=true to stop / ~servoTarget to retune".postln;
