// 90: drum-bus lift. The human one-shot voices (Groove MIDI kick/snare/hat) peak
// around 0.15-0.5 raw, where the LPViz drum loops arrive already mastered near 0.7.
// Raising stream gains alone was not enough, so the drum group insert is lifted here.
// Full scene state lives in 90.tidal; base mixer recall is still sc/groove71.scd.
~groupCtl.drums.set(1.7, 0.0, 0.0, 0.0);
~groupCtl.drums.getn(4, { |v| [\drumsGroupGain, v].postln });
