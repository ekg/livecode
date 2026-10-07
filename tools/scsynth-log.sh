#!/bin/sh
# Keep the engine's stdout/stderr off sclang's pipe (which can back up while
# compiling/loading samples), and preserve the actual failure across watchdog
# restarts. The foreground child stays in the plugin-owned process tree; keep
# its real exit status (including signals), which sclang's callback can obscure.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log="$root/sc/engine.log"
printf '\n=== scsynth pid %s — %s ===\n' "$$" "$(date -Is)" >> "$log"
# Engine-specific PipeWire client profile: the minimal client config, which
# includes module-rt so the engine asks for realtime scheduling for its data
# loop. Other applications and the user's PipeWire configuration are untouched.
export PIPEWIRE_CONFIG_NAME=client.conf
# REALTIME IS ENABLED. This launcher used to force SCHED_OTHER with
#   chrt --reset-on-fork --other 0 prlimit --rtprio=0:0
# to dodge an inherited 200ms RTTIME SIGKILL. That backfired: denying RT just
# pushed module-rt onto the rtkit-daemon fallback, which is what sets the 200ms
# RTTIME cap in the first place (verified: data-loop.0 was SCHED_RR 20 granted by
# rtkit while the process held RTPRIO 0/0 and RTTIME 200000).
# The user is in the audio/realtime groups (RLIMIT_RTPRIO 95, memlock unlimited)
# and the login session's RLIMIT_RTTIME is unlimited (sclang shows it), so
# module-rt now grants RT directly and the 200ms cap disappears. Do NOT
# reintroduce a chrt/prlimit clamp here; that reintroduces both problems.
"${SCSYNTH_BINARY:-/usr/bin/scsynth}" "$@" >> "$log" 2>&1
status=$?
printf '=== scsynth exit status %s — %s ===\n' "$status" "$(date -Is)" >> "$log"
exit "$status"
