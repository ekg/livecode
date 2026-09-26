// Live mixer scene for 64.tidal. Load through tidal_sc; no graph rebuild.
// Preserve the known-working output path and conservative master ceiling.
(
~masterSet.(\mGain, 0.8);
~masterSet.(\mCut, 11000);
~masterSet.(\mSat, 0.28);
~route[\send].value(\music, \delay, 0.2);
~route[\send].value(\music, \verb, 0.18);
~route[\send].value(\music, \shimmer, 0.08);
~route[\send].value(\bass, \delay, 0);
~route[\send].value(\bass, \verb, 0);
~route[\send].value(\drums, \verb, 0.035);
"64: dry low end, moving dub space above it".postln;
)
