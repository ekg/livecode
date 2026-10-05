#!/bin/sh
# Keep the engine's stdout/stderr off sclang's pipe (which can back up while
# compiling/loading samples), and preserve the actual failure across watchdog
# restarts. The foreground child stays in the plugin-owned process tree; keep
# its real exit status (including signals), which sclang's callback can obscure.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log="$root/sc/engine.log"
printf '\n=== scsynth pid %s — %s ===\n' "$$" "$(date -Is)" >> "$log"
# Diagnostic isolation: this engine alone uses PipeWire's non-RT client.
# The inherited 200ms hard RTTIME limit can otherwise SIGKILL the JACK thread.
# Other applications and the user's PipeWire configuration are untouched.
export PIPEWIRE_CONFIG_NAME=client.conf
# Drop inherited FIFO policy and prevent the engine re-enabling it. Keep the
# RESET_ON_FORK flag: clearing it requires CAP_SYS_NICE on this machine.
chrt --reset-on-fork --other 0 prlimit --rtprio=0:0 -- "${SCSYNTH_BINARY:-/usr/bin/scsynth}" "$@" >> "$log" 2>&1
status=$?
printf '=== scsynth exit status %s — %s ===\n' "$status" "$(date -Is)" >> "$log"
exit "$status"
