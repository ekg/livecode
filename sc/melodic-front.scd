// Exact live mixer checkpoint for 65–68, captured after the listener's approval.
// Evaluate through tidal_sc with the existing project DSP running.
// Changes controls only: no bus allocation, node replacement or graph rebuild.
// This deliberately preserves the FX-group sends and ricocheting percussion.
(
(mGain: 0.8, mGlue: 0.5, mSat: 0.28, mCut: 11000, mDuck: 0.08,
 mHpf: 28, mThresh: 0.3, mWidth: 0.9, mCeil: 0.79, mKnee: 0.55)
.keysValuesDo { |key, value| ~masterSet.(key, value) };
// [group gain, delay send, reverb send, shimmer send]
~groupCtl.drums.set(0.9, 0.06, 0.035, 0.0);
~groupCtl.bass.set(1.0, 0.0, 0.0, 0.0);
~groupCtl.music.set(1.35, 0.18, 0.18, 0.035);
~groupCtl.fx.set(1.05, 0.5, 0.55, 0.4);
// [return gain, feedback, low-pass cutoff, existing kick-duck amount]
~auxCtl.delay.set(0.55, 0.55, 2600, 0.5);
~auxCtl.verb.set(0.5, 0.0, 9000, 0.65);
~auxCtl.shimmer.set(0.45, 0.6, 4200, 0.2);
"Melodic-front checkpoint: forward voices, restrained whole-mix duck, preserved FX.".postln;
)
