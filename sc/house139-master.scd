// Scene 139: near-unity live master. The patch itself carries the level.
// Apply after SC boot: this.executeFile("/home/erik/livecode/sc/house139-master.scd");
// No auto-normalizer. Mild glue only on loud transients; retain 0.79 safety
// ceiling from dub_master.scd. 132's hotter master remains recallable.
(
~masterSet.(\mGain, 1.1);
~masterSet.(\mGlue, 0.72);
~masterSet.(\mThresh, 0.12);
~masterSet.(\mSat, 0.12);
~masterSet.(\mDuck, 0.08);
~masterSet.(\mCut, 17000);
~masterSet.(\mKnee, 0.7);
~masterSet.(\mCeil, 0.79);
"sc/house139-master.scd applied: source gain + gentle transient glue".postln;
)
