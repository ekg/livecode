/* Layer switches, read by init.scd at every boot (and by tidal_sc_reload).
   Take a stage out of the signal path here (no code edits needed):
     ~dspEnabled      false -> orbits write straight to HARDWARE: no master bus, no
                               Ndef(\dubMaster) gain/ceiling at all
     ~dspOrbitFx      false -> STOCK SuperDirt delay/reverb per orbit
                               (dirt_delay + dirt_reverb + dirt_monitor) instead of
                               our dub chain (dirt_dubdelay: ddDrive tanh, ddCross
                               crossfeed = flange, ddWow flutter; dirt_dubverb)
     ~routingEnabled  false -> no group buses, no aux sends, no phonon strips
     ~selftestEnabled false -> no boot-time instrument metering

   STOCK TIDAL MODE = all four false (the block below). Then Tidal's own orbit
   params are the FX: delay, delaytime, delayfeedback, room, size, dry, and the
   stock module set — and nothing of ours sits between the orbits and the card.
   Reload with tidal_sc_reload (no stack restart needed).
   NOTE: in stock mode there is no ~masterBus, so scene/deck mode must be LEFT
   (`tidal_scene leave`) or the channel mixers write to a bus nobody reads. */
~dspEnabled = false;
~dspOrbitFx = false;
~routingEnabled = false;
// OFF by default: the boot self-test fired a `bd` on every orbit, and orbits 5-11
// map to the music/fx GROUPS whose aux sends are 0.3-0.55, so the boot kicks came
// out reverbed and delayed for no reason. It is a diagnostic, not music. Turn it
// back on (then restart) only when hunting a silent-mix bug.
~selftestEnabled = false;
