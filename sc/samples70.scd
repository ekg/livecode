// Curated aliases into the user's library: no copying, no whole-library reload.
(
[
    [\p70drumA, "/home/erik/sounds/lpviz/2020_DD_96_DrumLp2.wav"],
    [\p70drumB, "/home/erik/sounds/lpviz/2020_DD_99_DrumLp6.wav"],
    [\p70synthA, "/home/erik/sounds/lpviz/2020_DD_99_SynthLp2_Cmin.wav"],
    [\p70synthB, "/home/erik/sounds/lpviz/2020_DD_99_SynthLp3_Cmin.wav"],
    [\p70perc, "/home/erik/sounds/lpviz/2020_DD_123_PercLp26.wav"],
    [\p70vox, "/home/erik/sounds/humanip/hmmm mmm.wav"],
    [\p70rhodes, "/home/erik/sounds/jrhodes/jRhodes Mezzo Piano D4.wav"],
    [\p70body, "/home/erik/sounds/cpluck/11_body_low.wav"],
    [\p70kick, "/home/erik/sounds/h2ogmbd/Kick-Med.wav"],
    [\p70snare, "/home/erik/sounds/h2ogmsn/Snare-Med.wav"],
    [\p70soft, "/home/erik/sounds/h2ogmsn/Snare-Soft.wav"],
    [\p70hat, "/home/erik/sounds/h2ogmhh/HatClosed-Med.wav"]
].do { |pair| ~dirt.soundLibrary.loadSoundFile(pair[1], pair[0]) };
"Scene 70 aliases installed: LPViz, voice, Rhodes, body percussion, acoustic kit.".postln;
)
