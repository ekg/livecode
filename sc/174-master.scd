// 174 master checkpoint: run after the DSP layer is installed; no routing changes.
(
~masterCtlBus.setn([0.9, 0.45, 0.06, 11000, 0.22, 48, 0.30, 1.0]);
Ndef(\dubMaster).set(\dWet, 0, \mKnee, 0.75, \mCeil, 0.85);
)
