// Complete sample recall for 85 (adds the second drum source on top of 80).
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples80.scd");
~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/lpviz/2020_RL_123_DrumLp1.wav", \p85drumA);
)
