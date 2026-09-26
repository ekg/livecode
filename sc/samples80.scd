// Complete sample recall for 80. Does not start patterns or change the mixer.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples76.scd");
[
    [\p80a, "2020_DD_117_SynthLp7_Dmaj.wav"],
    [\p80b, "2020_PH_124_SynthLp1_Dmaj.wav"],
    [\p80c, "2020_DD_120_SynthLp13_Amaj.wav"],
    [\p80d, "2020_DD_122_SynthLp21_Emaj.wav"]
].do { |pair| ~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/lpviz/" ++ pair[1], pair[0]) };
~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/cpluck/08_C4_plucked.wav", \p80pluck);
)
