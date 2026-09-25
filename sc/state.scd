/* SuperCollider state, applied at every boot by init.scd (~scLoad).
   Written by ~scSave; edit here for the next boot, or use ~scSet.value(\mGain, 0.9)
   live once SC eval is available.

   Kept as EXPLICIT calls: an earlier version iterated an Event with keysDo and
   raised "Message '+' not understood", which silently left the master at the
   file defaults. No loops here, so a failure is visible in sc/boot.log.

   Tuned for live performance: make-up gain up, glue gentle, peaks caught early,
   hard ceiling just under -2 dBFS. */
~scSet.value(\mGain,   1.3);   // make-up gain
~scSet.value(\mGlue,   0.5);   // compressor slope above threshold (smaller = more)
~scSet.value(\mSat,    0.3);   // tape saturation
~scSet.value(\mDuck,   0.3);   // kick ducking depth
~scSet.value(\mThresh, 0.3);   // compressor threshold
~scSet.value(\mCeil,   0.79);  // ceiling: limiter + hard clip
~scSet.value(\mKnee,   0.55);  // soft-clip knee
