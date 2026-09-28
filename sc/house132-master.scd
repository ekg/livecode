// Scene 132: Night Window live master preset. Apply AFTER init.scd:
// this.executeFile("/home/erik/livecode/sc/house132-master.scd");
//
// The scene measured RMS ~0.0184, envelope peak ~0.0635 with the boot master.
// This is a fixed, moderate lift, NOT an RMS auto-gain loop: sparse vocals
// should stay sparse and the quiet bars should stay quiet. The threshold makes
// glue engage only on the louder moments. Existing lookahead limiter and hard
// ceiling remain in dub_master.scd. Offline two-pass LUFS normalization is
// tools/master.py, not something to chase on every live bar.
(
~masterSet.(\mGain, 2.25);
~masterSet.(\mGlue, 0.68);
~masterSet.(\mThresh, 0.09);
~masterSet.(\mSat, 0.18);
~masterSet.(\mDuck, 0.16);
~masterSet.(\mCut, 17000);
~masterSet.(\mKnee, 0.68);
~masterSet.(\mCeil, 0.79);
"sc/house132-master.scd applied: fixed makeup, gentle glue, light tape, safe limiter".postln;
)
