// Replays can race a release against creation of a paused global effect.
// Retire orphan global FX by ownership, not by gate (the release may never
// have reached the node). Delayed until after the server's bundle grace.
(
~pruneDirtFX = {
    var server = s, group = ~dirt.group, responder;
    var synthSlot = GlobalDirtEffect.instVarNames.collect(_.asSymbol).indexOf(\synth);
    var owned = Set.new, names;
    if(synthSlot.isNil) { Error("unsupported GlobalDirtEffect layout: missing synth slot").throw };
    ~dirt.orbits.do { |orbit|
        orbit.globalEffects.do { |effect|
            var node = effect.instVarAt(synthSlot);
            if(node.notNil) { owned.add(node.nodeID) };
        };
    };
    // These are the stock/project ORBIT-global definitions, not event modules.
    names = ["dirt_dubdelay", "dirt_dubverb", "dirt_monitor", "dirt_delay",
        "dirt_reverb", "dirt_leslie", "dirt_rms"].collect { |name|
        (name ++ ~dirt.numChannels).asSymbol
    };
    responder = OSCFunc({ |msg|
        var index = 2, retired = List.new, walk;
        walk = {
            var id = msg[index], children = msg[index + 1];
            index = index + 2;
            if(children == -1) {
                var name = msg[index].asSymbol;
                index = index + 1;
                if(names.includes(name) and: { owned.includes(id).not }) { retired.add(id) };
            } { children.do { walk.value } };
        };
        walk.value;
        if(retired.notEmpty) {
            server.sendMsg('/n_free', *retired.asArray);
            "pruned % orphan Dirt FX nodes".format(retired.size).postln;
        };
    }, '/g_queryTree.reply', server.addr, argTemplate: [0]).oneShot;
    SystemClock.sched(2, { responder.free; nil }); // no responder leak on death
    server.sendMsg('/g_queryTree', group, 0);
};
)
