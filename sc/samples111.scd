// Vocal fragments for the chop layer. Source: ~/sounds/humanip (human vocal manipulations).
// Chosen for being SHORT (0.27-1.7s) so they can be cut into slices that read as
// texture/feeling rather than words. Longer ones (eeeeeee 3.2s, ayeee 1.3s) are included
// because they chop into more material.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "samples110.scd");
[
    [\vxA, "hmmm mmm.wav"],
    [\vxB, "oooh.wav"],
    [\vxC, "noo.wav"],
    [\vxD, "hummm.wav"],
    [\vxE, "eeeeeee.wav"],
    [\vxF, "ayeee.wav"],
    [\vxG, "high trill.wav"],
    [\vxH, "lo tone.wav"],
    [\vxI, "doot doot.wav"],
    [\vxJ, "inhale.wav"],
    [\vxK, "pfft.wav"],
    [\vxL, "whuup.wav"],
    [\vxM, "choppy.wav"],
    [\vxN, "repeater.wav"],
    [\vxO, "swoooosh.wav"]
].do { |p| ~dirt.soundLibrary.loadSoundFile("/home/erik/sounds/humanip/" ++ p[1], p[0]) };
"sc/samples111.scd loaded: 15 vocal fragments".postln;
)
