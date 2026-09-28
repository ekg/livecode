// Scene 140: dry, open house mix. Near-unity master, no normalization.
// Patch gains live in 140.tidal. Restrained group sends prevent the dark
// delay/verb/shimmer chain from masking the source loops and chords.
// Apply after boot: this.executeFile("/home/erik/livecode/sc/house140-master.scd");
(
~groupCtl.drums.set(1.0, 0.02, 0.02, 0);
~groupCtl.bass.set(1.0, 0, 0, 0);
~groupCtl.music.set(0.95, 0.08, 0.1, 0);
~groupCtl.fx.set(0.9, 0.03, 0.06, 0);
~auxCtl.delay.set(0.26, 0.34, 5000, 0.2);
~auxCtl.verb.set(0.22, 0, 11000, 0.15);
~auxCtl.shimmer.set(0, 0, 4200, 0);
~masterSet.(\mGain, 1.0);
~masterSet.(\mGlue, 0.84);
~masterSet.(\mThresh, 0.34);
~masterSet.(\mSat, 0.04);
~masterSet.(\mDuck, 0.02);
~masterSet.(\mCut, 19000);
~masterSet.(\mKnee, 0.92);
~masterSet.(\mCeil, 0.79);
"house140: dry groups, unity master, mild glue, safety limiter".postln;
)
