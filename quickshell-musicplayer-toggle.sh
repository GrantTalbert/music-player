#!/usr/bin/env bash
# quickshell-musicplayer-toggle.sh
#
# Used as the .desktop launcher's Exec, instead of calling
# `quickshell -c MusicPlayer` directly.
#
# Behavior (this is intentionally NOT a toggle despite the filename):
#   * if the GUI is already open -> do nothing
#   * if the GUI is closed / no instance running -> open it
#
# This works by calling the `show` IPC action (shell.qml's IpcHandler),
# which always sets visible = true, rather than `toggle`, which flips
# whatever the current state is. `show` is idempotent: calling it on an
# already-visible window is a harmless no-op, and calling it when the
# window was manually closed (windowLoader.active == false) recreates
# it and shows it. `toggle` looked like it worked half the time only
# because it alternates hide/show on every call, regardless of whether
# you actually wanted to hide it.
#
# If no quickshell instance is running at all, the ipc call itself
# fails (nothing is listening on the IPC bus for this config), and we
# fall back to spawning a new instance.

LOG=/tmp/quickshell-musicplayer.log

{
    echo "==== $(date) ===="
    echo "invoked as: $0 $*"
} >> "$LOG" 2>&1

QUICKSHELL_BIN="$(command -v quickshell || true)"
if [ -z "$QUICKSHELL_BIN" ]; then
    for candidate in "$HOME/.local/bin/quickshell" "$HOME/.cargo/bin/quickshell" "/usr/local/bin/quickshell" "/usr/bin/quickshell"; do
        [ -x "$candidate" ] && QUICKSHELL_BIN="$candidate" && break
    done
fi

if [ -z "$QUICKSHELL_BIN" ]; then
    echo "$(date): quickshell binary not found" >> "$LOG"
    exit 1
fi

if "$QUICKSHELL_BIN" -c MusicPlayer ipc call window makeVisible >>"$LOG" 2>&1; then
    echo "$(date): ipc makeVisible succeeded (instance already running, now visible)" >> "$LOG"
    exit 0
fi

echo "$(date): ipc makeVisible failed (no instance running) - starting a new one" >> "$LOG"
setsid -f "$QUICKSHELL_BIN" -c MusicPlayer >>"$LOG" 2>&1 </dev/null
echo "$(date): spawned new quickshell instance" >> "$LOG"
