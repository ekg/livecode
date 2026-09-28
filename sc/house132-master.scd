// Scene 132: Night Window live master preset. Apply AFTER init.scd:
// this.executeFile("/home/erik/livecode/sc/house132-master.scd");
//
// The first mix measured RMS ~0.0184, envelope peak ~0.0635 with the boot
// master. After a first makeup pass it averaged ~0.0356 RMS / peak ~0.235.
// The loop decks are now raised at source in 132.tidal; this preset adds
// gentle compression and a little more makeup, NOT an RMS auto-gain loop:
// sparse vocals
// should stay sparse and the quiet bars should stay quiet. The threshold makes
// glue engage only on the louder moments. Existing lookahead limiter and hard
// ceiling remain in dub_master.scd. Offline two-pass LUFS normalization is
// tools/master.py, not something to chase on every live bar.
(
~masterSet.(\mGain, 2.85);
~masterSet.(\mGlue, 0.76);     // ~1.3:1 above threshold; preserve transients
~masterSet.(\mThresh, 0.055); // meet loud loop/kick moments, not the vocal gaps
~masterSet.(\mSat, 0.15);
~masterSet.(\mDuck, 0.1);
~masterSet.(\mCut, 17000);
~masterSet.(\mKnee, 0.68);
~masterSet.(\mCeil, 0.79);
"sc/house132-master.scd applied: fixed makeup, gentle glue, light tape, safe limiter".postln;
)
