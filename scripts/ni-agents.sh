#!/usr/bin/env bash
# Stop NI's hardware agents before trying DECKARD with an MK3, and start them again
# afterwards for Maschine (macOS).
#
#   scripts/ni-agents.sh status   # which are running
#   scripts/ni-agents.sh stop     # quit them (Maschine must be closed first)
#   scripts/ni-agents.sh start    # open them again, as at login
#
# They are login items, not launchd jobs: once quit they stay down until opened again or
# the next login. NIHostIntegrationAgent holds the MK3's screens; NIHardwareAgent its
# pads, buttons and knobs.
set -euo pipefail

DIR="/Library/Application Support/Native Instruments/Hardware"
# The order they're started in: the hardware first, the integration on top of it.
AGENTS=(NIHardwareAgent NIHostIntegrationAgent)

[ "$(uname -s)" = Darwin ] || { echo "macOS only" >&2; exit 1; }

running() { pgrep -x "$1" >/dev/null; }

# Wait up to 10 s for an agent to reach the state asked for ("up" or "down").
wait_for() {
    for _ in $(seq 50); do
        if [ "$2" = up ] && running "$1"; then return 0; fi
        if [ "$2" = down ] && ! running "$1"; then return 0; fi
        sleep 0.2
    done
    return 1
}

status() {
    for a in "${AGENTS[@]}"; do
        if running "$a"; then echo "$a: running"; else echo "$a: stopped"; fi
    done
    if pgrep -f "Maschine [0-9].app/Contents/MacOS" >/dev/null; then echo "Maschine: running"; fi
}

stop() {
    # Maschine talks to the controller through them: quitting them under it would cut it
    # off, and quitting Maschine is the user's call (unsaved work).
    if pgrep -f "Maschine [0-9].app/Contents/MacOS" >/dev/null; then
        echo "Maschine is running: save and quit it first" >&2
        exit 1
    fi
    for a in "${AGENTS[@]}"; do
        if running "$a"; then
            pkill -x "$a"
            if wait_for "$a" down; then echo "$a: stopped"; else echo "$a: still running" >&2; exit 1; fi
        else
            echo "$a: already stopped"
        fi
    done
}

start() {
    for a in "${AGENTS[@]}"; do
        if running "$a"; then
            echo "$a: already running"
            continue
        fi
        [ -d "$DIR/$a.app" ] || { echo "$a: not installed at $DIR" >&2; exit 1; }
        # In the background, without taking focus, as at login.
        open -g -j "$DIR/$a.app"
        if wait_for "$a" up; then echo "$a: started"; else echo "$a: didn't start" >&2; exit 1; fi
    done
}

case "${1:-status}" in
    status) status ;;
    stop) stop ;;
    start) start ;;
    *) echo "usage: $0 [status|stop|start]" >&2; exit 2 ;;
esac
