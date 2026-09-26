// Clean variant; preserve the forward melodies, remove ricocheting aux layers.
// Controls only. Restore sc/melodic-front.scd for the original approved mix.
(
this.executeFile(thisProcess.nowExecutingPath.dirname +/+ "melodic-front.scd");
~groupCtl.drums.set(0.9, 0.0, 0.02, 0.0);
~groupCtl.fx.set(1.05, 0.06, 0.18, 0.0);
~groupCtl.music.set(1.35, 0.12, 0.18, 0.0);
~auxCtl.delay.set(0.35, 0.24, 2400, 0.5);
~auxCtl.shimmer.setAt(0, 0.0);
// Clear stale settings even on channels that are now silent.
~dirt.orbits.do { |orbit, i|
    if([0, 1, 2, 3, 4, 10].includes(i)) {
        orbit.setGlobalEffects(\ddSend, 0, \delaySend, 0, \delayfeedback, 0, \verbSend, 0, \room, 0)
    } {
        orbit.setGlobalEffects(\ddWow, 0, \ddCross, 1, \ddDrive, 0.08, \ddSend, 0.12, \delayfeedback, 0.25)
    }
};
"Clean melodic mix: dry percussion, restrained repeats, shimmer return off.".postln;
)
