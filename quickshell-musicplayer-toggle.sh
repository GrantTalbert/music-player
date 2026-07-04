#!/usr/bin/env bash
# quickshell-musicplayer-toggle.sh (diagnostic build)
#
# Used as the .desktop launcher's Exec, instead of calling
# `quickshell -c MusicPlayer` directly.
#
# This version logs everything -- including a full environment dump --
# to /tmp/quickshell-musicplayer.log every time it runs, so we can
# compare "launched from a terminal" vs "launched from rofi/wofi/
# fuzzel" and see exactly what's different (this is almost always
# WAYLAND_DISPLAY / DISPLAY / DBUS_SESSION_BUS_ADDRESS / XDG_RUNTIME_DIR
# being missing when a launcher spawns things through systemd/dbus
# activation instead of as a direct child of Hyprland).
#
# Once we've root-caused it, swap this back for the plain version.

LOG=/tmp/quickshell-musicplayer.log

{
    echo "==== $(date) ===="
    echo "invoked as: $0 $*"
    echo "whoami: $(whoami)"
    echo "pwd: $(pwd)"
    echo "---- relevant env ----"
    for var in WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
               HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE XDG_CURRENT_DESKTOP PATH; do
        printf '%s=%s\n' "$var" "${!var}"
    done
    echo "---- full env ----"
    env
    echo "-----------------------"
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

echo "$(date): using quickshell binary at $QUICKSHELL_BIN" >> "$LOG"

if "$QUICKSHELL_BIN" -c MusicPlayer ipc call window toggle >>"$LOG" 2>&1; then
    echo "$(date): ipc toggle succeeded" >> "$LOG"
    exit 0
fi

echo "$(date): ipc toggle failed (no instance running, or a real error above) - starting a new one" >> "$LOG"
setsid -f "$QUICKSHELL_BIN" -c MusicPlayer >>"$LOG" 2>&1 </dev/null
echo "$(date): spawned new quickshell instance" >> "$LOG"
