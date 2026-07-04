#!/usr/bin/env bash
# quickshell-musicplayer-toggle.sh
#
# Used as the .desktop launcher's Exec, instead of calling
# `quickshell -c MusicPlayer` directly.
#
# Calling quickshell directly every time spawns a brand new process on
# each launch, and none of them ever exit on their own - opening the
# player twice from a drun menu used to leave two full daemons/GUIs
# running, wasting resources, with no way back to a "closed" state
# short of pkill. `-n`/`--no-duplicate` doesn't fix this either: it
# just refuses to start the second instance with an error, it doesn't
# bring the existing window forward or let you close-then-reopen.
#
# The actual fix: keep exactly one quickshell process alive in the
# background and use Quickshell's own IPC (a separate mechanism from
# musicplayerd's unix socket - see shell.qml's IpcHandler) to tell it
# to show/hide its window. Only start a brand new process if none is
# running yet.

if quickshell -c MusicPlayer ipc call window toggle >/dev/null 2>&1; then
    exit 0
fi

# No instance was running (the ipc call above failed) - launch one,
# detached from this script so it survives after drun's own process
# exits, and redirected so drun doesn't wait on it or capture its output.
setsid -f quickshell -c MusicPlayer >/tmp/quickshell-musicplayer.log 2>&1 </dev/null
