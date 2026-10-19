// MIDI capture: log every keyboard note with a timestamp, and sound it so you can
// hear yourself over the Tidal mix.
//
//   sclang> this.executeFile("/home/erik/livecode/sc/midi-capture.scd")
//
// Writes JSONL to ~/midi-capture.jsonl:
//   first line: {"t0":<startTime>,"cps":<cycles per second at start>}
//   then:       {"t":<time>,"n":<midinote>,"v":<velocity>,"on":0|1,"cps":<cps>}
//
// Then convert to a Tidal pattern:
//   python3 tools/midi_to_tidal.py ~/midi-capture.jsonl
//
// Stop capture with: ~midiCaptureStop.value

(
var path = Platform.userHomeDir ++ "/midi-capture.jsonl";
var amp = 0.28;

MIDIClient.init;
MIDIIn.connectAll;

~midiPath = path;

~midiAppend = { |dict|
	File.use(path, "a", { |f|
		f.write(dict.keys.asArray.sort.collect { |k| "\"" ++ k ++ "\":" ++ dict[k] }.join(",").insert(0, "{").insert(-1, "}") ++ "\n");
	});
};

File.use(path, "w", { |f| f.write("{\"t0\":" ++ Main.elapsedTime.round(0.00001) ++ ",\"cps\":" ++ TempoClock.default.tempo.round(0.000001) ++ "}\n") });

~midiLog = { |note, vel, on|
	~midiAppend.((
		t: Main.elapsedTime.round(0.00001),
		n: note,
		v: vel,
		on: if(on, 1, 0),
		cps: TempoClock.default.tempo.round(0.000001)
	));
	// sound it so you can play over the mix
	if(on, {
		Synth(\default, [\freq, note.midicps, \amp, (vel / 127 * amp), \release, 0.6]);
	});
};

MIDIdef.noteOn(\midiCapOn, { |vel, note, chan|
	~midiLog.(note, vel, true);
	("note on  " ++ note).postln;
});

MIDIdef.noteOff(\midiCapOff, { |vel, note, chan|
	~midiLog.(note, vel, false);
	("note off " ++ note).postln;
});

~midiCaptureStop = {
	MIDIdef.noteOn(\midiCapOn).free;
	MIDIdef.noteOff(\midiCapOff).free;
	("capture stopped -> " ++ path).postln;
};

("MIDI capture ARMED -> " ++ path ++ "  (cps " ++ TempoClock.default.tempo.round(0.0001) ++ ")  -- play!").postln;
)
