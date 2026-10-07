/* Layer switches, read by init.scd at every boot (and by tidal_sc_reload).
   All stages are ON: the layer is verified end to end — dub fx + orbit chains,
   master chain with bus routing, group/aux mixing layer, boot self-test.

   Take one out of the signal path here (no code edits needed):
     ~dspEnabled      false -> orbits write straight to hardware, no master chain
     ~dspOrbitFx      false -> stock SuperDirt delay/reverb per orbit
     ~routingEnabled  false -> no group buses/aux sends (all orbits -> master)
     ~selftestEnabled false -> no boot-time instrument metering */
~dspEnabled = true;
~dspOrbitFx = true;
~routingEnabled = true;
// OFF by default: the boot self-test fired a `bd` on every orbit, and orbits 5-11
// map to the music/fx GROUPS whose aux sends are 0.3-0.55, so the boot kicks came
// out reverbed and delayed for no reason. It is a diagnostic, not music. Turn it
// back on (then restart) only when hunting a silent-mix bug.
~selftestEnabled = false;
