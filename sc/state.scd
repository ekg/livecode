/* saved SC state (see sc/README.md). Deliberately obvious values so the
   mechanism is verifiable: mGain 0.1 vs boot default 0.9. */
~scLoadedState = (
	mGain: 0.1,
);
~scLoadedState.keysValuesDo { |k, v| ~scSet.value(k, v) };
