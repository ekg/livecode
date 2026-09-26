// 93: swapped loop sources. breaklots / 300 breaks / loopmaster_producer_essentials.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples85.scd");
[
    [\p93drumA, "/home/erik/samples/breaklots/01 - Track01.wav"],
    [\p93drumB, "/home/erik/samples/300 breaks/12 - Track12.wav"],
    [\p93arp,   "/home/erik/samples/loopmaster_producer_essentials/arp1.wav"],
    [\p93arp2,  "/home/erik/samples/loopmaster_producer_essentials/arp2.wav"],
    [\p93str,   "/home/erik/samples/loopmaster_producer_essentials/Arp Odyssey String Sweep 2 A.wav"],
    [\p93perc,  "/home/erik/samples/loopmaster_producer_essentials/GHATAM 02.wav"]
].do { |p| ~dirt.soundLibrary.loadSoundFile(p[1], p[0]) };
)
