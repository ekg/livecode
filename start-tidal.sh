#!/bin/bash
# Boot SuperDirt + a Tidal REPL for this repo, in one terminal.
# Usage: ./start-tidal.sh          (paste .tidal chunks into the tidal> prompt)
#        hush                      stops all patterns; Ctrl-D exits (kills sclang too)

# clean up any leftover instance squatting on the OSC ports (57110/57120)
pkill -u "$USER" -x sclang 2>/dev/null; pkill -u "$USER" -x scsynth 2>/dev/null; sleep 1

cd "$(dirname "$0")"

# pipewire's libjack, so scsynth routes through pipewire instead of spawning a
# fighting jackd (this is what used to SIGABRT scsynth)
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/pipewire-0.3/jack

sclang &
SCLANG_PID=$!
trap 'kill $SCLANG_PID 2>/dev/null' EXIT

# wait for SuperDirt to finish loading sample banks (~30-60s first time)
for i in $(seq 1 60); do
  sleep 2
  if ss -uln 2>/dev/null | grep -q ":57120 "; then break; fi
done
echo ">>> SuperDirt listening on 57120 — starting Tidal REPL"

ghci -ghci-script BootTidal.hs
