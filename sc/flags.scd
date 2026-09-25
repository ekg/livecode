/* sc/flags.scd — runtime switches for the DSP layer, loaded by init.scd.
   ~dspEnabled  : route every orbit -> ~masterBus and run the master chain
                  (compressor, saturation, soft knee, limiter, clip ceiling, meter)
   ~dspOrbitFx  : replace each orbit's effect chain with our dub delay / dub reverb
   Both true = full layer. Both false = stock SuperDirt, untouched (safe mode).
   init.scd logs how many orbits actually reached the master bus, and warns if the
   routing is partial — that failure is otherwise silent and invisible. */
~dspEnabled = true;
~dspOrbitFx = true;
