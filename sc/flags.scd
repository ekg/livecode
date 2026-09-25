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
~selftestEnabled = true;
