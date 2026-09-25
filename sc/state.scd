/* SuperCollider state (loaded at every boot). Tuned for live performance:
   the master should hold a steady level with clear headroom, not pin on peaks.
   mGain 1.3 lifts the whole mix; mGlue 0.5 = gentle glue (smaller = more squash);
   mThresh 0.3 catches peaks early; ceiling 0.79 ≈ -2 dBFS. */
~scLoadedState = (
	mGain:   1.3,
	mGlue:   0.5,
	mSat:    0.3,
	mDuck:   0.3,
	mThresh: 0.3,
	mCeil:   0.79,
	mKnee:   0.55,
);
~scLoadedState.keysDo { |k| ~scSet.value(k, ~scLoadedState[k]) };
