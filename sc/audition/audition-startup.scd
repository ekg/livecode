/*
audition-startup.scd — startup file for the second, headless SuperCollider stack.

Loaded as sclang's startup file via sc/audition/config/SuperCollider/startup.scd,
which sclang selects because tools/audition/audition-ctl launches it with
XDG_CONFIG_HOME=sc/audition/config. The live ~/.config/SuperCollider/startup.scd
(-> superdirt_startup.scd) is therefore NEVER loaded by this process.

Boots scsynth on 57111 and SuperDirt on 57121, then mirrors the live DSP graph by
executing the real sc/init.scd through a symlink tree (see tools/audition/
audition-ctl and README.md). It never binds 57110/57120 and never writes
sc/boot.log.
*/
(
var auditionRoot = "/home/erik/livecode/sc/audition";
var bootLog = auditionRoot ++ "/boot.log";
var readyFile = auditionRoot ++ "/ready";
var log = { |s| ("[audition " ++ Main.elapsedTime.round(0.01) ++ "] " ++ s).postln };

// A fresh boot must be distinguishable from a stale one: init.scd truncates the
// graph log itself, but drop the ready sentinel now so status can never report
// a graph from a previous run.
if(File.exists(readyFile)) { File.delete(readyFile) };

// ------------------------------------------------------------------- scsynth
// Distinct Server + port so nothing collides with the live stack (scsynth 57110,
// SuperDirt 57120). Server.program is the audition-private engine-log wrapper;
// livecode/tools/scsynth-log.sh (which logs to live sc/engine.log) is NOT used.
Server.program = auditionRoot ++ "/scsynth-log.sh";
Server.default = Server(\audition, NetAddr("127.0.0.1", 57111));
s = Server.default;
s.options.numBuffers = 1024 * 256;
s.options.memSize = 8192 * 256;
s.options.numWireBufs = 2048;
s.options.maxNodes = 1024 * 32;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 0;   // headless: never create capture ports
s.options.useSystemClock = false;    // matches the live file
s.options.blockSize = 256;           // matches the live file
s.latency = 0.3;
log.("booting scsynth 57111 / SuperDirt 57121");

s.waitForBoot {
	~dirt.stop;
	~dirt = SuperDirt(2, s);
	~dirt.doNotReadYet = true;
	~dirt.loadSoundFiles;
	~dirt.loadSoundFiles("/home/erik/sounds/*");
	~dirt.loadSoundFiles("/home/erik/sounds/mars_symlinks/*");
	~dirt.loadSoundFiles("/home/erik/drummachines/*");
	// Same 4 scene channels x 6 local orbits as the live stack (~dirt.start(57120, 0 ! 24)).
	~dirt.start(57121, 0 ! 24);
	SuperDirt.default = ~dirt;
	log.("SuperDirt listening on 57121, % orbits".format(~dirt.orbits.size));

	// Mirror the live DSP graph. Platform.userHomeDir is overridden at class-
	// compile time (sc/audition/classes/PlatformAuditionHome.sc, pulled in via
	// sc/audition/config/SuperCollider/sclang_conf.yaml) to the audition runtime
	// home, so init.scd loads the real graph code through symlinks while writing
	// its home-derived artifacts (boot.log, master-meter.log, spectrum.log,
	// state.scd, ctl.log) under sc/audition only.
	this.executeFile(Platform.userHomeDir ++ "/livecode/sc/init.scd");

	// Fail loudly: init.scd logs "[t] ok ..." per stage, "[t] FAIL ..." when a
	// stage dies, and "[t] done" as its last line. A graph that did not install
	// must not look "ready".
	if(File.exists(bootLog)) {
		var text = File.readAllString(bootLog);
		if(text.contains("FAIL").not and: { text.contains("done") }) {
			File.use(readyFile, "w", { |f| f.write("ready " ++ Date.getDate.stamp ++ "\n") });
			log.("AUDITION READY — graph installed");
		} {
			log.("AUDITION GRAPH FAILED — see %".format(bootLog));
		};
	} {
		log.("AUDITION GRAPH FAILED — no log at %".format(bootLog));
	};

	// Convenient orbit aliases, same shape as the live startup.
	(
		~d1 = ~dirt.orbits[0]; ~d2 = ~dirt.orbits[1]; ~d3 = ~dirt.orbits[2];
		~d4 = ~dirt.orbits[3]; ~d5 = ~dirt.orbits[4]; ~d6 = ~dirt.orbits[5];
		~d7 = ~dirt.orbits[6]; ~d8 = ~dirt.orbits[7]; ~d9 = ~dirt.orbits[8];
		~d10 = ~dirt.orbits[9]; ~d11 = ~dirt.orbits[10]; ~d12 = ~dirt.orbits[11];
		~d13 = ~dirt.orbits[12]; ~d14 = ~dirt.orbits[13]; ~d15 = ~dirt.orbits[14];
		~d16 = ~dirt.orbits[15]; ~d17 = ~dirt.orbits[16]; ~d18 = ~dirt.orbits[17];
		~d19 = ~dirt.orbits[18]; ~d20 = ~dirt.orbits[19]; ~d21 = ~dirt.orbits[20];
		~d22 = ~dirt.orbits[21]; ~d23 = ~dirt.orbits[22]; ~d24 = ~dirt.orbits[23];
	);
};
)
