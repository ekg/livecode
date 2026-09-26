// 94: real one-bar breakbeats for d1, on top of the 93 loop sources.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples93.scd");
[
    [\p94brkA, "Funky 6 A 108.5bpm.wav"],
    [\p94brkB, "Funky 3 A 115bpm.wav"],
    [\p94brkC, "Phat 11 A 111bpm.wav"],
    [\p94brkD, "2step 5 130bpm.wav"]
].do { |p| ~dirt.soundLibrary.loadSoundFile("/home/erik/samples/loopmaster_producer_essentials/" ++ p[1], p[0]) };
)
