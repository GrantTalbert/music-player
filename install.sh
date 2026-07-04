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
QUICKSHELL_DEST="$HOME/.config/quickshell"
CONFIG_DEST="$HOME/.config/quickshell-musicplayer"
ICON_DEST="$HOME/.local/share/icons/hicolor/128x128/apps"
DESKTOP_DEST="$HOME/.local/share/applications"

mkdir -p "$(dirname "$DAEMON_DEST")" "$QUICKSHELL_DEST" "$CONFIG_DEST" "$ICON_DEST" "$DESKTOP_DEST"

# currently just running the daemon from here
# rm -rf "$DAEMON_DEST"
# cp -r "$SCRIPT_DIR/daemon" "$DAEMON_DEST"

rm -rf "$QUICKSHELL_DEST/MusicPlayer"
cp -r "$SCRIPT_DIR/quickshell/MusicPlayer" "$QUICKSHELL_DEST/MusicPlayer"

if [ -d "$SCRIPT_DIR/config" ]; then
    cp -r "$SCRIPT_DIR/config/." "$CONFIG_DEST/"
fi

cp "$SCRIPT_DIR/icon.svg" "$ICON_DEST/quickshell-musicplayer.svg"