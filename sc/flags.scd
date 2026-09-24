/* sc/flags.scd — runtime switches for the DSP layer, loaded by init.scd.
   Delete this file (or set true) to re-enable our routing. */
~dspEnabled = false;   // false = SAFE MODE: SuperDirt's stock routing, untouched
