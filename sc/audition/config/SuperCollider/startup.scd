// Startup file for the audition sclang. Selected because sclang is launched with
// XDG_CONFIG_HOME=sc/audition/config, so it reads
// sc/audition/config/SuperCollider/startup.scd — never the live
// ~/.config/SuperCollider/startup.scd (which would load superdirt_startup.scd
// and bind the live ports).
"/home/erik/livecode/sc/audition/audition-startup.scd".load;
