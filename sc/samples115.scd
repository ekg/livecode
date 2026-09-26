// Bowed (cbow) and plucked (cpluck) string samples from ~/sounds, for the melody voice.
//
// These are per-note recordings (C2..C5). Register is chosen by picking the sample;
// fine pitch within the octave is set with `speed` ratios, NOT `up` - `up` does not
// reach SuperDirt for plain samples (verified: speed stayed 1.0 on every event).
// Semitone n above the sample root = 2 ** (n/12):
//   +1 = 1.0595  +2 = 1.1225  +4 = 1.2599  +6 = 1.4142  +7 = 1.4983  +9 = 1.6818  +11 = 1.8877
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples111.scd");
[
    [\cb2,  "04_C2_bowed_long.wav"],
    [\cb3,  "05_C3_bowed_long.wav"],
    [\cb4,  "06_C4_bowed_long.wav"],
    [\cb5,  "07_C5_bowed_long.wav"],
    [\cb3s, "09_C3_bowed_short_hammered.wav"],
    [\cb4s, "10_C4_bowed_short_hammered.wav"],
    [\cp3,  "04_C3_pluck_long.wav"],
    [\cp4,  "08_C4_plucked.wav"],
    [\cp5,  "09_C5_plucked.wav"],
    [\cpg,  "10_ghost_pluck.wav"]
].do { |p| ~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/" ++ (if(p[0].asString.beginsWith("cb"), "cbow/", "cpluck/")) ++ p[1], p[0]) };
"sc/samples115.scd loaded: 4 bowed + 6 plucked string samples".postln;
)
