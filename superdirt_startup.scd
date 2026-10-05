/*
This is an example startup file. You can load it from your startup file
(to be found in Platform.userAppSupportDir +/+ "startup.scd")
*/

(
// Preserve engine errors across recovery and avoid stdout pipe backpressure.
Server.program = Platform.userHomeDir ++ "/livecode/tools/scsynth-log.sh";
// no s.reboot here: a fresh sclang is never booted, and reboot caused a boot race that cleanly killed the server
	// configure the sound server: here you could add hardware specific options
	// see http://doc.sccode.org/Classes/ServerOptions.html
	s.options.numBuffers = 1024 * 256; // increase this if you need to load more samples
	s.options.memSize = 8192 * 256; // increase this if you get "alloc failed" messages
	s.options.numWireBufs = 2048; // increase this if you get "exceeded number of interconnect buffers" messages
	s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
	s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
	s.options.numInputBusChannels = 0; // output-only Tidal stack: never create PipeWire mic capture ports
	s.options.useSystemClock = false; // SC 3.13 default (true) makes scsynth exit cleanly with pipewire-jack
	// boot the server and start SuperDirt
	s.waitForBoot {
		~dirt.stop; // stop any old ones, avoid duplicate dirt (if it is nil, this won't do anything)
		~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
		// lazy loading: register banks but read files on first use. This MUST come
		// before any loadSoundFiles call — eagerly reading the full Dirt-Samples
		// tree (~450 MB of buffers in one burst) crashes scsynth under pipewire-jack
		// with a clean "Server exited with exit code 0" a few seconds after boot.
		~dirt.doNotReadYet = true;
		~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
		// for example: ~dirt.loadSoundFiles("/Users/myUserName/Dirt/samples/*");
        ~dirt.loadSoundFiles("/home/erik/sounds/*");
        ~dirt.loadSoundFiles("/home/erik/sounds/mars_symlinks/*");
		// s.sync; // optionally: wait for samples to be read
		~dirt.start(57120, 0 ! 24);   // 4 scene channels x 6 local orbits — MUST match
		// sc/scene-mixer.json ({"channels":4,"orbits":6}), which the plugin reads.
		// SuperDirt fixes the orbit count here at boot: too few orbits and the
		// plugin refuses to install the mixer rather than mis-routing events.
		// our DSP layer: dub delay + dub reverb per orbit, master chain, extra
		// instruments. Defined here (not in the pi-tidal plugin) because sclang
		// runs this file on every boot — see sc/init.scd for the architecture.
		this.executeFile(Platform.userHomeDir ++ "/livecode/sc/init.scd");
		SuperDirt.default = ~dirt; // make this instance available in sclang (optional)

		// optional, needed for convenient access from sclang:
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
	s.latency = 0.3; // increase this if you get "late" messages
);
