/*
surface.scd — a small, legible control surface over the audio graph.

The problem this solves: from Tidal everything about SuperCollider is invisible.
You cannot see the graph, what exists in it, what is manipulable, whether it is
running, or how to undo a change. This file makes those five things explicit:

    ~scState            -> post the whole graph as readable text
    ~scGet(\masterGain) -> read one value
    ~scSet(\masterGain, 0.6)        -> change something (remembered for undo)
    ~scSet(\send, [\music, \delay, 0.5])
    ~scUndo             -> step back
    ~scReset            -> back to the boot state
    ~scTrace(true)      -> log the control bus + master values every 2s to sc/ctl.log
    ~scAlive            -> is the audio side actually running

Conventions that keep it simple:
  * every manipulable thing is named, and lives in ~sc.slots (an Event). One
    place to look for "what can I touch".
  * each slot is a getter/setter pair onto a control bus or a node argument, so
    SC-side changes and Tidal-side modulation drive the SAME value. Nothing is
    duplicated, so nothing can drift.
  * undo is a stack of closures, and the boot state is captured once, so
    "go back" always means something concrete.
*/
(
// ---------------------------------------------------------------- boot defaults
// captured once, so ~scReset restores exactly what the layer started with
~scBoot = (
	masterGain: 0.9, masterGlue: 0.6, masterSat: 0.28, masterTone: 13000,
	masterDuck: 0.3, groupGain: 1.0, sendDelay: 0.45, sendVerb: 0.3,
	sendShimmer: 0.25, auxDelay: 0.55, auxVerb: 0.5, auxShimmer: 0.45,
);

// ---------------------------------------------------------------- slot table
// name -> [getter, setter]. Getters read the live value; setters write it.
// Reading/writing goes through control buses where one exists, so Tidal and
// SC are always looking at the same number.
~scSlots = ();

// master chain: values live on the Ndef itself (dub_master.scd). ~masterSet is
// the single writer, so the surface and the audio cannot disagree.
if(~masterVals.notNil) {
	~masterVals.keys.asArray.do { |key|
		~scSlots.put(key, [
			{ ~masterVals[key] },
			{ |v| ~masterSet.value(key, v) },
		]);
	};
};

// group/aux sends, if the routing layer is up
if(~route.notNil and: { ~groups.notNil }) {
	~groups.keys.asArray.do { |name|
		var idx = ["drums", "bass", "music", "fx"].indexOf(name);
		if(idx.notNil) {
			#[\groupGain, \sendDelay, \sendVerb, \sendShimmer].do { |slot, i|
				var key = (slot.asString ++ name.asString).asSymbol;
				~scSlots.put(key, [
					{ ~groupCtl[name].getSynchronous(i) },
					{ |v| ~groupCtl[name].setAt(i, v) },
				]);
			};
		};
	};
};

// ---------------------------------------------------------------- history
~scHistory = [];
~scPos = 0;

~sc = ();

~scAlive = {
	var ok = s.serverRunning and: { ~dirt.notNil };
	if(ok) {
		"% synths, % ugens".format(s.numSynths, s.avgCPU.round(0.001)).postln;
	} { "scsynth is NOT running".warn };
	ok;
};

// post the graph: what exists, what it is connected to, what you can touch
~scState = {
	"--- audio graph ---".postln;
	"scsynth: %  (synths: %)".format(
		if(s.serverRunning) { "running" } { "DOWN" }, s.numSynths).postln;
	if(~masterBus.notNil) {
		"master bus: %   hardware out: 0/1".format(~masterBus.index).postln;
	};
	~dirt.orbits.do { |orbit, i|
		"orbit % -> bus %   fx: %".format(
			i, orbit.outBus.asString,
			orbit.globalEffects.collect { |e| e.name.asString }.join(" -> ")).postln;
	};
	if(~groups.notNil) {
		"groups:  %".format(~groups.keys.asArray.join("  ")).postln;
		"auxes:   %".format(~aux.keys.asArray.join("  ")).postln;
	} {
		"(routing layer not started: ~routingEnabled = false)";
	};
	if(~scSlots.notNil) { ~scSlots.keys.asArray.sort.do { |k|
		// defensive: a getter can return nil (unallocated bus, dead node), and
		// nil does not respond to round
		"  slot % = %".format(k, (~scGet.value(k) ? "n/a")).postln;
	} } { "  (no slots registered yet)".postln };
	"--- end of graph ---".postln;
};

~scGet = { |name|
	var slot = ~scSlots[name];
	if(slot.isNil) { ("no such slot: " ++ name).warn; nil } { slot[0].value };
};

~scSet = { |name, value|
	var slot = ~scSlots[name];
	if(slot.isNil) {
		("no such slot: " ++ name).warn;
	} {
		var old = slot[0].value;
		slot[1].value(value);
		~scHistory = ~scHistory.keep(~scPos) + [ [name, old] ];
		~scPos = ~scHistory.size;
		"set % = %  (was %)".format(name, value, old ? "n/a").postln;
	};
};

~scUndo = {
	if(~scPos <= 0) { "nothing to undo".postln } {
		var entry = ~scHistory[~scPos - 1];
		var slot = ~scSlots[entry[0]];
		~scPos = ~scPos - 1;
		slot[1].value(entry[1]);
		"undo % -> %".format(entry[0], entry[1] ? "n/a").postln;
	};
};

~scRedo = {
	if(~scPos >= ~scHistory.size) { "nothing to redo".postln } {
		var entry = ~scHistory[~scPos];
		var slot = ~scSlots[entry[0]];
		~scPos = ~scPos + 1;
		slot[1].value(entry[1]);
		"redo % -> %".format(entry[0], entry[1] ? "n/a").postln;
	};
};

~scReset = {
	~scBoot.keysValuesDo { |name, value|
		var slot = ~scSlots[name];
		if(slot.notNil) { slot[1].value(value) };
	};
	~scHistory = [];
	~scPos = 0;
	"reset to boot state".postln;
};

// ---------------------------------------------------------------- save / load
// The state of the SuperCollider side, written to a file so it can be versioned
// next to a .tidal state. Slots are named values (see ~scSlots), so "save"
// means: write the current value of every slot. Load applies them back.
//
// Convention:  sc/state.scd        — the current session's SC state
//              sc/states/<NN>.scd  — the SC state that belongs to <NN>.tidal
~scStatePath = Platform.userHomeDir ++ "/livecode/sc/state.scd";

~scFormatState = {
	var lines = ["/* generated by ~scSave — SuperCollider state for the saved .tidal file.",
		"   Loaded automatically by init.scd if present; delete the file for defaults. */",
		"~scLoadedState = ("];
	if(~scSlots.notNil) {
		~scSlots.keys.asArray.sort.do { |k|
			var v = ~scGet.value(k);
			if(v.notNil) { lines = lines.add("\t%: %,".format(k.asString, v)) };
		};
	};
	lines.add(");");
	lines.add("~scLoadedState.keysValuesDo { |k, v| ~scSet.value(k, v) };");
	lines.join("\n") ++ "\n";
};

~scSave = { |path|
	var target = path ? ~scStatePath;
	File.use(target, "w", { |f| f.write(~scFormatState.value) });
	"saved % slot(s) -> %".format(~scSlots.size, target).postln;
	target;
};

~scLoad = {
	// The argument is deliberately IGNORED: in this environment ~scLoad.value
	// arrives with the ~sc Event as its argument, and probing its type
	// (.isString) raised "Non Boolean in test". The path is a constant anyway.
	var target = ~scStatePath;
	if(target.isKindOf(String)) {
		if(File.exists(target)) {
			thisProcess.interpreter.executeFile(target);
			"loaded SC state from %".format(target).postln;
		} {
			"no saved state at % — using boot defaults".format(target).postln;
		};
	} {
		"~scLoad: state path invalid (%)".format(target).warn;
	};
};

// ---------------------------------------------------------------- trace
// Samples the control bus and master values into sc/ctl.log, so you can SEE
// whether Tidal parameters are actually arriving (this is what was missing when
// the m* bridge silently did nothing).
~scTraceRoutine = nil;
~scTrace = { |on = true|
	if(on) {
		if(~scTraceRoutine.notNil) { "already tracing".postln } {
			var file = File(Platform.userHomeDir ++ "/livecode/sc/ctl.log", "w");
			~scTraceRoutine = Routine({
				loop {
					var line = "%  %".format(
						Date.getDate.stamp,
						~scSlots.keys.asArray.sort.collect { |k|
							"%:%".format(k, (~scGet.value(k) ? "n/a"))
						}.join(" "));
					file.write(line ++ "\n");
					file.flush;
					2.wait;
				}
			}).play(AppClock);
			"tracing to livecode/sc/ctl.log (every 2s) — ~scTrace(false) to stop".postln;
		};
	} {
		if(~scTraceRoutine.notNil) { ~scTraceRoutine.stop; ~scTraceRoutine = nil };
		"trace stopped".postln;
	};
};

"surface: % slot(s) available".format(~scSlots.size).postln;
)
