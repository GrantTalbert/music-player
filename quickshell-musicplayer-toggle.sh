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

QUICKSHELL_BIN="$(command -v quickshell || true)"
if [ -z "$QUICKSHELL_BIN" ]; then
    for candidate in "$HOME/.local/bin/quickshell" "$HOME/.cargo/bin/quickshell" "/usr/local/bin/quickshell" "/usr/bin/quickshell"; do
        [ -x "$candidate" ] && QUICKSHELL_BIN="$candidate" && break
    done
fi

if [ -z "$QUICKSHELL_BIN" ]; then
    exit 1
fi

if "$QUICKSHELL_BIN" -c MusicPlayer ipc call window makeVisible >>"$LOG" 2>&1; then
    exit 0
fi

setsid -f "$QUICKSHELL_BIN" -c MusicPlayer >>"$LOG" 2>&1 </dev/null
