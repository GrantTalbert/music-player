#!/usr/bin/bash

# Get the directory this script resides in (resolves symlinks)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
	DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
	SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
	[[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"

mv "$SCRIPT_DIR/daemon" "~/.local/share/quickshell-musicplayer/daemon"
mv "$SCRIPT_DIR/quickshell/MusicPlayer" "~/.config/quickshell"
mv "$SCRIPT_DIR/config/*" "~/.config/quickshell-musicplayer"