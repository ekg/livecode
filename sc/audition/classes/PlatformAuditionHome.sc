/*
PlatformAuditionHome.sc — audition-stack class extension.

Compiled into the audition sclang only, via sc/audition/config/SuperCollider/
sclang_conf.yaml includePaths. It redirects Platform.userHomeDir to the audition
runtime home so the home-derived paths inside the mirrored DSP graph resolve
under sc/audition/ instead of the live tree:

  init.scd:43      sc = Platform.userHomeDir ++ "/livecode/sc"   (graph root + boot.log)
  dub_master.scd   ~meterLog     -> sc/audition/runtime/home/livecode/sc/master-meter.log
  spectrum.scd     ~spectrumLog  -> .../spectrum.log
  surface.scd      ~scStatePath  -> .../state.scd, ~scTrace -> .../ctl.log

The runtime home mirrors the real sc/ as per-entry symlinks; tools/audition/
audition-ctl builds it. This is a compile-time class extension (not a runtime
`+` in the startup file) because sclang only accepts class-extension syntax in
class-library files.

userAppSupportDir and userConfigDir are SEPARATE C++ primitives and are NOT
affected, so SuperDirt, mi-UGens and the downloaded quarks still resolve
normally.
*/
+ Platform {
	*userHomeDir { ^"/home/erik/livecode/sc/audition/runtime/home" }
}
