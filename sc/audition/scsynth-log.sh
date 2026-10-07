#!/bin/sh
# Private scsynth launcher for the audition stack.
#
# Mirrors livecode/tools/scsynth-log.sh but writes sc/audition/engine.log so the
# live sc/engine.log is never touched. Keeping scsynth's stdout/stderr off
# sclang's pipe avoids backpressure while sclang compiles/loads samples.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log="$root/engine.log"
printf '\n=== audition scsynth pid %s — %s ===\n' "$$" "$(date -Is)" >> "$log"
# Minimal PipeWire client profile (includes module-rt so the engine asks for RT).
export PIPEWIRE_CONFIG_NAME=client.conf
"${SCSYNTH_BINARY:-/usr/bin/scsynth}" "$@" >> "$log" 2>&1
status=$?
printf '=== audition scsynth exit status %s — %s ===\n' "$status" "$(date -Is)" >> "$log"
exit "$status"
