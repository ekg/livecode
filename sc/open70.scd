// Brighter corpus mix: do not confuse dark processing with sample character.
// Keep the established routing and safety ceiling; controls only.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "melodic-clean.scd");
~masterSet.(\mCut, 18000);
~masterSet.(\mSat, 0.1);
~masterSet.(\mGlue, 0.8);
~masterSet.(\mThresh, 0.5);
~masterSet.(\mDuck, 0.04);
~groupCtl.drums.set(0.9, 0, 0, 0);
~groupCtl.music.set(1.35, 0.1, 0.14, 0);
~groupCtl.fx.set(1.0, 0.0, 0.08, 0);
"Open corpus mix: dry drums, 18kHz master cutoff, light saturation/compression.".postln;
)
