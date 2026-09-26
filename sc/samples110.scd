// 808 drum kit aliases. Completely different drum sound from the h2ogm acoustic kit
// (p70kick / p70snare / p70hat) used up to 110. Loaded with explicit names rather than
// relying on SuperDirt's directory-index ordering, which is alphabetical and fragile.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples94.scd");
[
    [\k808L,     "808_Kick_Long.wav"],
    [\k808S,     "808_Kick_Short.wav"],
    [\s808a,     "808_Snare_1.wav"],
    [\s808b,     "808_Snare_2.wav"],
    [\h808C,     "808_Hat_Closed.wav"],
    [\h808O,     "808_Hat_Open.wav"],
    [\h808P,     "808_Hat_Pedal.wav"],
    [\c808,      "808_Clap.wav"],
    [\cb808,     "808_Cowbell.wav"],
    [\cn808,     "808_Conga.wav"],
    [\cy808,     "808_Cymbal.wav"],
    [\sh808,     "808_Shaker.wav"],
    [\t808H,     "808_Tom_Hi.wav"],
    [\t808M,     "808_Tom_Mid.wav"],
    [\t808Lo,    "808_Tom_Low.wav"]
].do { |p| ~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/h2o808/" ++ p[1], p[0]) };
"sc/samples110.scd loaded: 15 x 808 kit aliases".postln;
)
