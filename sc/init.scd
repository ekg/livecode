/*
init.scd — install the dub FX layer into a running SuperDirt.

Called from superdirt_startup.scd right after ~dirt.start, i.e. sclang runs this
every time the stack boots. It writes every step (and any error, with a stack
trace) to sc/boot.log, because sclang's stdout is not readable from outside the
pi-tidal plugin — a silent failure here would otherwise look like "no sound".

LESSONS THAT SHAPED THIS FILE (all paid for in hours, 2026-09-25):
  1. A parse error in a file executed with executeFile is SILENT (executeFile
     returns nil, throws nothing). Countermeasure: loadStage() + sentinels —
     a file that dies quietly can no longer log "ok".
  2. THE BIG ONE: SuperDirt builds every orbit's effect chain EAGERLY at
     ~dirt.start, with the STOCK effects and outBus=0 (the "0 ! 12" argument).
     Setting orbit.globalEffects / orbit.outBus afterwards changes only the
     PROPERTIES — the live chain synths keep writing where they were born
     (direct to hardware). That is how a whole evening of "layer installed"
     boots produced stock chains to bus 0 while our mixer sat unused and
     silent. Countermeasure below: set final properties, then FREE AND REBUILD
     every chain (orbit.group.freeAll; orbit.initNodeTree) so the synths are
     born correct. initNodeTree does NOT free old chains by itself — calling
     it repeatedly just stacks copies (we found three per orbit).
  3. "ok" must mean AUDIO FLOWS, not "code ran". Synth(...) on an
     unregistered def fails ON THE SERVER (/s_new SynthDef not found) without
     throwing in sclang; strip synths died silently for a whole session.
     Countermeasures: s.sync between def-adding and synth-creating; every
     strip is .register'ed and its liveness checked; and the audio self-test
     fires a real bd event PER ORBIT and meters it end to end — a silent
     orbit is a FAIL with its number in boot.log, and the plugin's readiness
     check refuses to call the stack ready while any FAIL line exists.

Orbit layout after boot (see also routing.scd):
  group buses: drums/bass/music/fx, summed into the master bus, which feeds
  the master chain (dub_master.scd) and then hardware. Orbits map to groups
  via ~orbitGroupMap (all 12 orbits are assigned).

Flags (sc/flags.scd overrides the defaults below):
  ~dspOrbitFx      use our dub chain instead of stock delay/reverb
  ~routingEnabled  start the group/aux mixing layer
  ~selftestEnabled gate the boot on per-orbit audio
*/
(
var sc = Platform.userHomeDir ++ "/livecode/sc";
var logFile = File(sc ++ "/boot.log", "w");
var log = { |s|
	var line = "[" ++ Main.elapsedTime.round(0.01) ++ "] " ++ s;
	logFile.write(line ++ "\n");
	logFile.flush;
	line.postln;
};
var stage = { |name, func|
	try { func.value; log.("ok   " ++ name) } { |err|
		log.("FAIL " ++ name ++ " -> " ++ err.errorString);
	};
};
// like stage(), but for executing a scd FILE — and immune to the silent
// parse-error trap: the file must set its sentinel (~scLoadedXxx = true) on
// its last line, or the stage FAILs no matter how quietly it died.
var loadStage = { |name, path, sentinel|
	currentEnvironment.put(sentinel, nil);
	try {
		this.executeFile(path);
	} { |err|
		log.("FAIL " ++ name ++ " -> " ++ err.errorString);
	};
	if(currentEnvironment.at(sentinel).isNil) {
		log.("FAIL " ++ name ++ " -> file did not execute (silent parse error)");
	} {
		log.("ok   " ++ name);
	};
};

// ---------------------------------------------------------------------------
// flags
// ---------------------------------------------------------------------------
~dspOrbitFx = true;
~routingEnabled = true;
~selftestEnabled = true;
if(File.exists(sc ++ "/flags.scd")) { this.executeFile(sc ++ "/flags.scd") };
log.("dub FX install starting; server running: " ++ s.serverRunning
	++ "   orbitFx: " ++ ~dspOrbitFx
	++ "   routing: " ++ ~routingEnabled
	++ "   selftest: " ++ ~selftestEnabled);

// 1 ----------------------------------------------------------------- define
loadStage.("define fx", sc ++ "/dub_fx.scd", \scLoadedFx);
loadStage.("define master", sc ++ "/dub_master.scd", \scLoadedMaster);
loadStage.("load param manifest", sc ++ "/params_gen.scd", \dirtParamGroups);
loadStage.("load routing layer", sc ++ "/routing.scd", \scLoadedRouting);
loadStage.("load demo synth", sc ++ "/demo_synth.scd", \scLoadedDemo);
loadStage.("load surface", sc ++ "/surface.scd", \scLoadedSurface);
loadStage.("load selftest helpers", sc ++ "/selftest.scd", \scLoadedSelftest);
stage.("load saved SC state", { ~scLoad.value });

// 2 --------------------------------- defs on the SERVER, and buses present
s.sync;
stage.("verify defs and buses", {
	var want = ["dirt_dubdelay2", "dirt_dubverb2", "dirt_tape2",
		"dubchord", "dubsub", "tapestab",
		"phononGroup2", "phononAuxDelay2", "phononAuxVerb2", "phononAuxShimmer2"];
	var have = SynthDescLib.global.synthDescs.keys.collect(_.asString);
	var missing = want.reject { |w| have.includes(w) };
	var busMissing = [];
	// buses the graph needs — nil here means a file above silently failed
	if(~masterBus.isNil) { busMissing = busMissing.add("~masterBus") };
	[\drums, \bass, \music, \fx].do { |g|
		if(~groups[g].isNil) { busMissing = busMissing.add("~groups." ++ g) } };
	[\delay, \verb, \shimmer].do { |a|
		if(~aux[a].isNil) { busMissing = busMissing.add("~aux." ++ a) } };
	log.("     defs missing: " ++ if(missing.isEmpty) { "none" } { missing.join(" ") });
	log.("     buses missing: " ++ if(busMissing.isEmpty) { "none" } { busMissing.join(" ") });
	if(missing.notEmpty) { Error("missing defs: " ++ missing.join(" ")).throw };
	if(busMissing.notEmpty) { Error("missing buses: " ++ busMissing.join(" ")).throw };
});

// 3 --------------------------------------------------------- rebuild orbits
// THE fix: SuperDirt created every chain eagerly at ~dirt.start (stock fx,
// outBus=0 → hardware). Properties set afterwards are dead letters. So: set
// the FINAL globalEffects and outBus, then free the old chains and rebuild.
// freeAll is safe: event synthGroups are created lazily per event (DirtEvent),
// and buses survive; initNodeTree re-plays globalEffects with CURRENT values.
// NB: initNodeTree never frees — it only adds (hence: freeAll first, always).
stage.("rebuild orbit chains", {
	~dirt.orbits.do { |orbit|
		orbit.outBus = ~masterBus;
		if(~dspOrbitFx) {
			orbit.globalEffects = [
				GlobalDirtEffect(\dirt_dubdelay,
					[\ddSend, \ddLp, \ddHp, \ddDrive, \ddWow, \ddCross, \ddDuck,
					 \delaytime, \delayfeedback, \delaySend, \lock, \cps]),
				GlobalDirtEffect(\dirt_dubverb,
					[\verbSend, \room, \verbT60, \verbDamp, \size, \verbEarly,
					 \verbHp, \verbPre, \verbLow, \verbHigh, \verbLowcut,
					 \verbHighcut, \verbTone, \verbMod, \verbWidth]),
				GlobalDirtEffect(\dirt_monitor, [\limitertype]).alwaysRun_(true),
			];
		} {
			orbit.globalEffects = [
				GlobalDirtEffect(\dirt_delay,
					[\delaytime, \delayfeedback, \delaySend, \delayAmp, \lock, \cps]),
				GlobalDirtEffect(\dirt_reverb, [\size, \room, \dry]),
				GlobalDirtEffect(\dirt_monitor, [\limitertype]).alwaysRun_(true),
			];
		};
	};
	// group-map overrides (routing layer): point mapped orbits at group buses
	if(~routingEnabled and: { ~orbitGroupMap.notNil }) {
		~orbitGroupMap.keysValuesDo { |idx, grp|
			if(~groups[grp].notNil) { ~dirt.orbits[idx].outBus = ~groups[grp] };
		};
	};
	// now the rebuild: kill every stale chain, recreate with final properties
	~dirt.orbits.do { |orbit| orbit.group.freeAll };
	s.sync;
	~dirt.orbits.do { |orbit| orbit.initNodeTree };
	s.sync;
	log.("     % orbits rebuilt; 0->%  5->%  8->%".format(~dirt.orbits.size,
		~dirt.orbits[0].outBus.index, ~dirt.orbits[5].outBus.index,
		~dirt.orbits[8].outBus.index));
});

// 4 --------------------------------------------------- routing strips, LIVE
// The strips sum group buses into master and run the aux returns. Previously
// they died silently (defs not yet on the server, /s_new fails server-side
// with no sclang error). Now: created after s.sync, registered with
// NodeWatcher, and their liveness is checked — dead strip = FAIL, not "ok".
if(~routingEnabled) { stage.("start routing layer", {
	var dead;
	if(~routingNodes.notNil) { ~routingNodes.do { |n| n.free } };
	~routingNodes = [];
	s.sync;
	~startRouting.();
	s.sync;
	~routingNodes.do { |n| n.register };
	0.2.wait;
	dead = ~routingNodes.reject { |n| n.isPlaying };
	log.("     % strips (4 group + 3 aux)".format(~routingNodes.size));
	if(~routingNodes.size != 7) { Error("expected 7 strips, got %".format(~routingNodes.size)).throw };
	if(dead.notEmpty) { Error("strips not playing: " ++ dead.size).throw };
	log.("     all strips playing (NodeWatcher-verified)");
}) } { log.("     routing layer NOT started (~routingEnabled = false)") };

// 5 ------------------------------------------------------------------ modules
stage.("register tape module", {
	~dirt.addModule(\tape, { |dirtEvent|
		dirtEvent.sendSynth('dirt_tape' ++ ~dirt.numChannels,
			[tape: ~tape, tapeHf: ~tapeHf, tapeHiss: ~tapeHiss, tapeWow: ~tapeWow,
			 out: ~out]);
	}, { ~tape.notNil });
});

// 6 ------------------------------------------------------- audio self-test
// The boot gate: fire a real bd event per orbit, meter the master bus AND the
// hardware bus. An orbit that produces no level anywhere is a FAIL with its
// number in boot.log. Also detects wholesale bypass (signal on hardware but
// none on master = stale chains writing straight to hardware) and a dead
// master chain (master has signal, hardware does not).
if(~selftestEnabled) { stage.("audio self-test (per orbit)", {
	if(thisThread.isKindOf(Routine).not) {
		log.("     skipped: audio self-test runs at boot only");
	} {
		var ctlM = Bus.control(s, 1);
		var ctlH = Bus.control(s, 1);
		var net = NetAddr("127.0.0.1", 57120);
		var synthM, synthH;
		var dead = 0, masterSeen = 0, hwSeen = 0;
		SynthDef(\bootPeak, { |in, out|
			Out.kr(out, PeakFollower.ar(In.ar(in, 2).sum, 1.0));
		}).add;
		s.sync;
		~dirt.orbits.do { |orbit, i|
			var levelM, levelH;
			synthM !? { synthM.free };
			synthH !? { synthH.free };
			// fresh peak-holders per orbit, so one orbit's peak can't mask
			// the next one's silence
			synthM = Synth(\bootPeak, [\in, ~masterBus.index, \out, ctlM.index],
				s, \addToTail);
			synthH = Synth(\bootPeak, [\in, 0, \out, ctlH.index],
				s, \addToTail);
			net.sendMsg("/dirt/play", "s", "bd", "n", 0, "orbit", i,
				"gain", 1.0, "cps", 0.333, "cycle", 0, "delta", 1);
			0.7.wait;
			levelM = ctlM.getSynchronous(0);
			levelH = ctlH.getSynchronous(0);
			if(levelM > 0.005) { masterSeen = masterSeen + 1 };
			if(levelH > 0.005) { hwSeen = hwSeen + 1 };
			if((levelM < 0.005) and: { levelH < 0.005 }) {
				dead = dead + 1;
				log.("     !! orbit %: NO AUDIO anywhere (master %, hw %)"
					.format(i, levelM, levelH));
			} {
				log.("     orbit % ok: master %  hw %"
					.format(i, levelM.round(0.01), levelH.round(0.01)));
			};
		};
		synthM !? { synthM.free };
		synthH !? { synthH.free };
		ctlM.free; ctlH.free;
		log.("     paths: %/% orbits hit master, %/% hit hardware"
			.format(masterSeen, ~dirt.orbits.size, hwSeen, ~dirt.orbits.size));
		if((hwSeen > 0) and: { masterSeen == 0 }) {
			log.("     !! BYPASS: audio reaches hardware but never the master");
			log.("     bus — stale chains are writing straight to hardware");
			dead = dead + 1;
		};
		if((masterSeen > 0) and: { hwSeen == 0 }) {
			log.("     !! MASTER CHAIN DEAD: master bus has signal, hardware");
			log.("     does not — the Ndef/master chain is not passing audio");
			dead = dead + 1;
		};
		if(dead > 0) { Error("audio self-test: % problem(s) — see above".format(dead)).throw };
	};
}) } { log.("     audio self-test skipped (~selftestEnabled = false)") };

// 7 -------------------------------------------------------------------- report
try {
	var orbitReport;
	log.("orbits -> " ++ if(~routingEnabled and: { ~orbitGroupMap.notNil }) {
		orbitReport = ~orbitGroupMap.keys.collect { |k| k ++ ":" ++ ~orbitGroupMap[k] }.join(" ");
		"group buses: " ++ orbitReport
	} {
		"master bus " ++ ~masterBus.index
	});
	log.("orbit fx:  " ++ ~dirt.orbits[0].globalEffects.collect(_.name).join(" -> "));
	log.("master:    hpf -> glue(duck from orbit0) -> tape -> tone -> limiter");
	log.("instruments: dubchord dubsub tapestab;  module: tape");
	log.("routing:   ~route[\orbit].value(i, \group) / ~route[\send].value / ~route[\levels].value");
	log.("Tidal params: dd*  verb*  tape*  (room/delaytime/delayfeedback still work)");
} { |err| log.("     !! report skipped: " ++ err.errorString) };
log.("done");
logFile.close;
)
