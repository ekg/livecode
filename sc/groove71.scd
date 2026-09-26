// Drum-forward, less crowded recall. Open filters are retained.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "open70.scd");
~groupCtl.drums.set(1.25, 0, 0, 0);
~groupCtl.music.set(1.1, 0.08, 0.14, 0);
~groupCtl.fx.set(0.8, 0, 0.06, 0);
"71: drum pocket forward, space between melodic voices, master remains open.".postln;
)
