/* saved SuperCollider state for the current .tidal file.
   Written by ~sc.save in SuperCollider; applied at stack boot by init.scd
   (delete the file to fall back to the boot defaults).
   masterGain 0.35 = obvious on purpose, so the mechanism is verifiable. */
~scLoadedState = (
	demoCutoff: 400,
	demoDrive: 0.05,
	mGain: 0.35,
);
~scLoadedState.keysValuesDo { |k, v| ~sc.set(k, v) };
