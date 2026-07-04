#!/usr/bin/bash

# Get the directory this script resides in (resolves symlinks)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
	DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
	SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
	[[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"


DAEMON_DEST="$HOME/.local/share/quickshell-musicplayer/daemon"
BIN_DEST="$HOME/.local/share/quickshell-musicplayer/bin"
QUICKSHELL_DEST="$HOME/.config/quickshell"
CONFIG_DEST="$HOME/.config/quickshell-musicplayer"
ICON_DEST="$HOME/.local/share/icons/hicolor/128x128/apps"
DESKTOP_DEST="$HOME/.local/share/applications"

mkdir -p "$(dirname "$DAEMON_DEST")" "$BIN_DEST" "$QUICKSHELL_DEST" "$CONFIG_DEST" "$ICON_DEST" "$DESKTOP_DEST"

# currently just running the daemon from here
# rm -rf "$DAEMON_DEST"
# cp -r "$SCRIPT_DIR/daemon" "$DAEMON_DEST"

rm -rf "$QUICKSHELL_DEST/MusicPlayer"
cp -r "$SCRIPT_DIR/quickshell/MusicPlayer" "$QUICKSHELL_DEST/MusicPlayer"

if [ -d "$SCRIPT_DIR/config" ]; then
    cp -r "$SCRIPT_DIR/config/." "$CONFIG_DEST/"
fi

cp "$SCRIPT_DIR/icon.svg" "$ICON_DEST/quickshell-musicplayer.svg"

# ---- single-instance launcher ---------------------------------------
# Installs the wrapper script that toggles an already-running
# quickshell instance's window instead of spawning a new process every
# time the app is launched from drun (see bin/quickshell-musicplayer-toggle.sh
# for why this is necessary), and bakes its real installed path into
# the .desktop entry's Exec line.
cp "$SCRIPT_DIR/bin/quickshell-musicplayer-toggle.sh" "$BIN_DEST/toggle.sh"
chmod +x "$BIN_DEST/toggle.sh"

sed "s|__TOGGLE_SCRIPT__|$BIN_DEST/toggle.sh|" "$SCRIPT_DIR/quickshell-musicplayer.desktop" \
    > "$DESKTOP_DEST/quickshell-musicplayer.desktop"
chmod +x "$DESKTOP_DEST/quickshell-musicplayer.desktop"

echo "Installed. If you have an old quickshell-musicplayer.desktop entry"
echo "or leftover 'quickshell -c MusicPlayer' processes from before this"
echo "change, kill them once now (pkill -f 'quickshell -c MusicPlayer')"
echo "so future launches go through the new toggle script instead."
