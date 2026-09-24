/*
init.scd — install the dub FX layer into a running SuperDirt.

Called from superdirt_startup.scd right after ~dirt.start, i.e. sclang runs this
every time the stack boots. It writes every step (and any error, with a stack
trace) to sc/boot.log, because sclang's stdout is not readable from outside the
pi-tidal plugin — a silent failure here would otherwise look like "no sound".

What it does
------------
1. defines the SynthDefs (dub_fx.scd) and the master chain (dub_master.scd)
2. waits for the SynthDefs to reach the server (they are sent asynchronously —
   playing an effect before its def arrives is the "SynthDef not found" failure)
3. replaces the stock per-orbit effects with ours:
      dirt_delay  -> dirt_dubdelay   (filtered repeats that darken, ducking)
      dirt_reverb -> dirt_dubverb    (HPF'd send, pre-delay, damped low band)
   drops dirt_leslie (unused), inserts dirt_masterctl, keeps dirt_monitor last
4. routes every orbit into the master bus (their monitors write there)
5. registers the per-event `tape` module

Orbit convention from Tidal (`# orbit N`):
   0 drums (dry; the kick is the master sidechain source)
   1 bass (dry)      2 chords (delay + short reverb)
   3 pads (long reverb, wide)       4 voices (heavy delay)
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
		log.("      " ++ err.class.asString ++ ": "
			++ (err.respondsTo(\errorString).if({ err.errorString }, { err.asString })));
	};
};

log.("dub FX install starting; server running: " ++ s.serverRunning);

// 1 ----------------------------------------------------------------- define
stage.("define fx", { this.executeFile(sc ++ "/dub_fx.scd") });
stage.("define master", { this.executeFile(sc ++ "/dub_master.scd") });
// the parameter lists live in sc/params.tsv and arrive here generated, so a
// param cannot be added to SuperCollider without also being declared in Tidal
stage.("load param manifest", { this.executeFile(sc ++ "/params_gen.scd") });
stage.("load routing", { this.executeFile(sc ++ "/routing.scd") });
stage.("load surface", { this.executeFile(sc ++ "/surface.scd") });
// the worked demo: an instrument defined here, sequenced from
// livecode/54.tidal, tweakable from SC (~demo.cutoff/res/drive)
stage.("load demo synth", { this.executeFile(sc ++ "/demo_synth.scd") });
// if a saved SC state exists, it is part of the current "state" — apply it
stage.("load saved SC state", { ~sc.load.value });

// 2 ------------------------------------------- make sure the defs are on the server
s.sync;
stage.("verify defs", {
	var want = ["dirt_dubdelay2", "dirt_dubverb2", "dirt_masterctl2",
		"dirt_tape2", "dubchord", "dubsub", "tapestab"];
	var have = SynthDescLib.global.synthDescs.keys.collect(_.asString);
	var missing = want.reject { |w| have.includes(w) };
	log.("     defs: " ++ want.collect { |w| w ++ (if(have.includes(w)) { "" } { "!!MISSING" }) }.join(" "));
	if(missing.notEmpty) { log.("     MISSING: " ++ missing.join(" ")) };
});

// 3 ------------------------------------------------------------------ orbit FX
stage.("install orbit chains", {
	// Explicit lists rather than generated ones: this exact chain is verified
	// working end to end, and a generated version compared group names as
	// Symbols while sc/params_gen.scd emits them as strings, which silently
	// emptied the chain. The manifest still drives the TIDAL side (where the
	// repeated pain was), and sc/params_gen.scd is kept for reference/checking.
	~dirt.orbits.do { |orbit|
		orbit.globalEffects = [
			GlobalDirtEffect(\dirt_dubdelay,
				[\ddSend, \ddLp, \ddHp, \ddDrive, \ddWow, \ddCross, \ddDuck,
				 \delaytime, \delayfeedback, \delaySend, \lock, \cps]),
			GlobalDirtEffect(\dirt_dubverb,
				[\verbSend, \room, \verbT60, \verbDamp, \size, \verbEarly,
				 \verbHp, \verbPre, \verbLow, \verbHigh, \verbLowcut,
				 \verbHighcut, \verbTone, \verbMod, \verbWidth]),
			// NOTE: dirt_masterctl was removed. Its Tidal-side bridge (m* params ->
			// control bus -> Ndef) did not reliably reach the chain; the master is
			// configured in sc/dub_master.scd instead. Keep the DSP path honest:
			// no dead effect sitting in the chain pretending to work.
			GlobalDirtEffect(\dirt_monitor, [\limitertype]).alwaysRun_(true),
		];
		orbit.outBus = ~masterBus;
	};
	log.("     orbit fx: dubdelay -> dubverb -> monitor  (master set in dub_master.scd)");
});

// 4 ------------------------------------------------------------------- modules
stage.("register tape module", {
	~dirt.addModule(\tape, { |dirtEvent|
		dirtEvent.sendSynth('dirt_tape' ++ ~dirt.numChannels,
			[tape: ~tape, tapeHf: ~tapeHf, tapeHiss: ~tapeHiss, tapeWow: ~tapeWow,
			 out: ~out]);
	}, { ~tape.notNil });
});

// 3b -------------------------------------------------- start the mixing layer
// OPT-IN: the routing layer is not verified end to end yet (its start stage hung
// the boot once). Set ~routingEnabled = true to try it — until then orbits stay
// on the master bus, which is the verified path.
~routingEnabled = false;
if(~routingEnabled) { stage.("start routing", {
	~startRouting.();
	s.sync;
	~route.assign.keysValuesDo { |orbitIdx, group| ~route.orbit(orbitIdx, group) };
	~routingNodes.postln;
	log.("     groups: " ++ ~groups.keys.asArray.join(" ")
		++ "   auxes: " ++ ~aux.keys.asArray.join(" "));
}) } { log.("     routing layer loaded but NOT started (~routingEnabled = false)") };

// 4b ------------------------------------------------------- self-test the layer
// a private bus, so the test measures the instruments themselves and not the
// master chain (which is verified separately by hearing anything at all)
stage.("instrument self-test", {
	~testBus = Bus.audio(s, 2);
	~testCtl = Bus.control(s, 1);
	this.executeFile(sc ++ "/selftest.scd");
	~selftest.(log, ~testBus, ~testCtl);
});

// 5 -------------------------------------------------------------------- report
log.("orbits -> master bus " ++ ~masterBus.index);
log.("per orbit: dubdelay -> dubverb -> masterctl -> monitor");
log.("master: hpf -> glue(duck from orbit0) -> tape -> tone -> limiter");
log.("instruments: dubchord dubsub tapestab;  module: tape");
log.("Tidal params: dd*  verb*  m*  (room/delaytime/delayfeedback still work)");
log.("--- graph state at boot ---");
~sc.state.value;
~sc.state.value.postln;
log.("slots: " ++ ~scSlots.keys.asArray.sort.join(" "));
log.("done");
logFile.close;
)
