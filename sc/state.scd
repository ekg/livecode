/* SuperCollider state for the current piece. Loaded at every boot by init.scd
   (~scLoad). Written by ~scSave inside SuperCollider; edit here to set values
   for the next boot, or use ~scSet.value(\mGain, 0.9) live.

   NB: this file overrides the defaults in sc/dub_master.scd — a leftover
   diagnostic value here (mGain 0.1) once made everything but the kick inaudible. */
~scLoadedState = (
	mGain:   0.9,    // master pre-gain
	mGlue:   0.42,   // compressor slope above threshold (smaller = more compression)
	mSat:    0.34,   // tape saturation
	mDuck:   0.38,   // kick ducking depth
	mThresh: 0.28,   // compressor threshold
	mCeil:   0.79,   // limiter/clip ceiling (≈ -2 dBFS sample peak)
	mKnee:   0.55,   // soft-clip knee (amplitude)
);
~scLoadedState.keysValuesDo { |k, v| ~scSet.value(k, v) };
