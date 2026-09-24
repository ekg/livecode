/*
surface.scd — a small, legible control surface over the audio graph.

The problem this solves: from Tidal everything about SuperCollider is invisible.
You cannot see the graph, what exists in it, what is manipulable, whether it is
running, or how to undo a change. This file makes those five things explicit:

    ~sc.state            -> post the whole graph as readable text
    ~sc.get(\masterGain) -> read one value
    ~sc.set(\masterGain, 0.6)        -> change something (remembered for undo)
    ~sc.set(\send, [\music, \delay, 0.5])
    ~sc.undo             -> step back
    ~sc.reset            -> back to the boot state
    ~sc.trace(true)      -> log the control bus + master values every 2s to sc/ctl.log
    ~sc.alive            -> is the audio side actually running

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
// captured once, so ~sc.reset restores exactly what the layer started with
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

// master chain controls live on the master control bus (dub_master.scd)
if(~masterCtlBus.notNil) {
	~scSlots.put(\masterGain, {
		[ { ~masterCtlBus.getSynchronous(0) }, { |v| ~masterCtlBus.setAt(0, v) } ] });
	~scSlots.put(\masterGlue, {
		[ { ~masterCtlBus.getSynchronous(1) }, { |v| ~masterCtlBus.setAt(1, v) } ] });
	~scSlots.put(\masterSat, {
		[ { ~masterCtlBus.getSynchronous(2) }, { |v| ~masterCtlBus.setAt(2, v) } ] });
	~scSlots.put(\masterTone, {
		[ { ~masterCtlBus.getSynchronous(3) }, { |v| ~masterCtlBus.setAt(3, v) } ] });
	~scSlots.put(\masterDuck, {
		[ { ~masterCtlBus.getSynchronous(4) }, { |v| ~masterCtlBus.setAt(4, v) } ] });
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

~sc.alive = {
	var ok = s.serverRunning and: { ~dirt.notNil };
	if(ok) {
		"% synths, % ugens".format(s.numSynths, s.avgCPU.round(0.001)).postln;
	} { "scsynth is NOT running".warn };
	ok;
};

// post the graph: what exists, what it is connected to, what you can touch
~sc.state = {
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
	~scSlots.keys.asArray.sort.do { |k|
		// defensive: a getter can return nil (unallocated bus, dead node), and
		// nil does not respond to round
		"  slot % = %".format(k, (~sc.get(k) ? "n/a")).postln;
	};
	"--- end of graph ---".postln;
};

~sc.get = { |name|
	var slot = ~scSlots[name];
	if(slot.isNil) { ("no such slot: " ++ name).warn; nil } { slot[0].value };
};

~sc.set = { |name, value|
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

~sc.undo = {
	if(~scPos <= 0) { "nothing to undo".postln } {
		var entry = ~scHistory[~scPos - 1];
		var slot = ~scSlots[entry[0]];
		~scPos = ~scPos - 1;
		slot[1].value(entry[1]);
		"undo % -> %".format(entry[0], entry[1] ? "n/a").postln;
	};
};

~sc.redo = {
	if(~scPos >= ~scHistory.size) { "nothing to redo".postln } {
		var entry = ~scHistory[~scPos];
		var slot = ~scSlots[entry[0]];
		~scPos = ~scPos + 1;
		slot[1].value(entry[1]);
		"redo % -> %".format(entry[0], entry[1] ? "n/a").postln;
	};
};

~sc.reset = {
	~scBoot.keysValuesDo { |name, value|
		var slot = ~scSlots[name];
		if(slot.notNil) { slot[1].value(value) };
	};
	~scHistory = [];
	~scPos = 0;
	"reset to boot state".postln;
};

// ---------------------------------------------------------------- trace
// Samples the control bus and master values into sc/ctl.log, so you can SEE
// whether Tidal parameters are actually arriving (this is what was missing when
// the m* bridge silently did nothing).
~scTraceRoutine = nil;
~sc.trace = { |on = true|
	if(on) {
		if(~scTraceRoutine.notNil) { "already tracing".postln } {
			var file = File(Platform.userHomeDir ++ "/livecode/sc/ctl.log", "w");
			~scTraceRoutine = Routine({
				loop {
					var line = "%  %".format(
						Date.getDate.stamp,
						~scSlots.keys.asArray.sort.collect { |k|
							"%:%".format(k, (~sc.get(k) ? "n/a"))
						}.join(" "));
					file.write(line ++ "\n");
					file.flush;
					2.wait;
				}
			}).play(AppClock);
			"tracing to livecode/sc/ctl.log (every 2s) — ~sc.trace(false) to stop".postln;
		};
	} {
		if(~scTraceRoutine.notNil) { ~scTraceRoutine.stop; ~scTraceRoutine = nil };
		"trace stopped".postln;
	};
};

"surface: % slot(s) available".format(~scSlots.size).postln;
)
