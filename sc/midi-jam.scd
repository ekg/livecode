// midi-jam.scd — play a MIDI keyboard over the running Tidal stack.
//
//   this.executeFile("/home/erik/livecode/sc/midi-jam.scd");
//   ~jamStart.(3);          // route the keyboard to orbit 3
//   ~jamStop.value;         // keyboard off, all jam notes released
//   ~jamCaptureStart.value; // log every note to ~/midi-capture.jsonl
//   ~jamCaptureStop.value;
//
// WHY IT IS BUILT THIS WAY (each of these was a real failure)
// ----------------------------------------------------------
// 1. SYNTHS LIVE INSIDE THE ORBIT GROUP. A synth created with plain Synth(...)
//    goes into the server's default group, which SuperDirt's panic does NOT
//    touch - one stuck note then rings through every `tidal_panic` and looks
//    like the stack is broken. Targeting ~dirt.orbits[n].group means
//    ~dirt.orbits[n].freeSynths (and therefore panic) reaches them.
//
// 2. A LIST OF SYNTHS PER NOTE, not one. Keying a Dictionary by note number and
//    overwriting means a repeated note-on orphans the previous synth, which then
//    never receives gate 0 and sustains forever. This was the "still ringing".
//
// 3. A HARD maxTime CAP. If a note-off is lost (panic, MIDI dropout, unplugged
//    cable) the synth still frees itself. Belt and braces on top of (2).
//
// 4. MIDIIn.disconnectAll ON STOP. Removing the MIDIdef stops new notes but the
//    RP2040 keeps sending; disconnecting makes "off" actually mean off.
//
// Tidal cannot take MIDI at all in this build (no MIDI dependency, no
// Sound.Tidal.MIDI module), so SuperCollider is the only entry point. Routing to
// an orbit's dryBus puts the keyboard through that orbit's delay/reverb and the
// master chain, exactly like a Tidal pattern.

(
var capturePath = Platform.userHomeDir ++ "/midi-capture.jsonl";

// ---------------------------------------------------------------- voice
SynthDef(\midiJam, { |out = 0, freq = 440, amp = 0.35, gate = 1, rel = 0.2, maxTime = 8|
	var env = EnvGen.kr(Env.asr(0.005, 1, rel), gate, doneAction: 2);
	var guard = Line.kr(1, 0, maxTime, doneAction: 2);
	var sig = Mix(Pulse.ar(freq * [1, 1.003], 0.5, 0.22)) + SinOsc.ar(freq, 0, 0.25);
	sig = LPF.ar(sig, 2800);
	Out.ar(out, sig * env * guard * amp);
}).add;

~jamOrbit = 3;
~jamSynths = Dictionary.new;
~jamActive = false;

// ---------------------------------------------------------------- on / off
~jamOn = { |note, vel|
	if(~jamActive) {
		var key = note.asSymbol;
		var list = ~jamSynths[key] ?? { ~jamSynths[key] = List.new };
		list.add(Synth(\midiJam, [
			\out, ~dirt.orbits[~jamOrbit].dryBus,
			\freq, note.midicps,
			\amp, (vel / 127 * 0.45),
			\maxTime, 6
		], ~dirt.orbits[~jamOrbit].group));   // (1) inside the orbit group
	};
};

~jamOff = { |note|
	var key = note.asSymbol;
	~jamSynths[key] !? { |list|
		list.do { |n| if(n.isPlaying) { n.set(\gate, 0) } };
		list.clear;
	};
};

// release everything without tearing down the handlers
~jamReleaseAll = {
	~jamSynths.do { |list| list.do { |n| if(n.isPlaying) { n.set(\gate, 0) } } };
	~jamSynths.clear;
};

// ---------------------------------------------------------------- start / stop
~jamStart = { |orbit = 3|
	~jamOrbit = orbit;
	~jamReleaseAll.value;
	MIDIIn.connectAll;                       // (4)
	MIDIdef.noteOn(\jamOn, { |vel, note, chan| ~jamOn.(note, vel) });
	MIDIdef.noteOff(\jamOff, { |vel, note, chan| ~jamOff.(note) });
	~jamActive = true;
	("jam ON -> orbit " ++ ~jamOrbit
		++ "  dryBus " ++ ~dirt.orbits[~jamOrbit].dryBus.index).postln;
};

~jamStop = {
	~jamActive = false;
	MIDIdef.noteOn(\jamOn).free;
	MIDIdef.noteOff(\jamOff).free;
	~jamReleaseAll.value;
	MIDIIn.disconnectAll;
	"jam OFF; MIDI disconnected, all jam notes released".postln;
};

// ---------------------------------------------------------------- capture
~jamCaptureStart = {
	File.use(capturePath, "w", { |f|
		f.write("{\"t0\":" ++ Main.elapsedTime.round(0.00001)
			++ ",\"cps\":" ++ TempoClock.default.tempo.round(0.000001) ++ "}\n");
	});
	~jamLog = { |note, vel, on|
		File.use(capturePath, "a", { |f|
			f.write("{\"t\":" ++ Main.elapsedTime.round(0.00001)
				++ ",\"n\":" ++ note ++ ",\"v\":" ++ vel
				++ ",\"on\":" ++ (if(on, 1, 0)) ++ "}\n");
		});
	};
	MIDIdef.noteOn(\jamCapOn, { |vel, note, chan| ~jamLog.(note, vel, true) });
	MIDIdef.noteOff(\jamCapOff, { |vel, note, chan| ~jamLog.(note, vel, false) });
	("capture -> " ++ capturePath).postln;
};

~jamCaptureStop = {
	MIDIdef.noteOn(\jamCapOn).free;
	MIDIdef.noteOff(\jamCapOff).free;
	("capture stopped -> " ++ capturePath).postln;
};

("midi-jam loaded.  ~jamStart.(3)  |  ~jamStop.value  |  "
	++ "~jamCaptureStart.value").postln;
)
