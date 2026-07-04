#!/usr/bin/env python3
"""
musicplayerd.py - the background daemon for the Quickshell music player.

Responsibilities:
  * scans ~/Music (or --music-dir) for tracks
  * plays audio via mpv (python-mpv)
  * persists playlists + favorites
  * exposes itself as an MPRIS2 player over D-Bus
  * exposes a unix-socket JSON control protocol for the Quickshell GUI

Run it with --help for options. See the project README for install
instructions (mpv, python-mpv, mutagen, python-dbus, python-gobject).
"""
from __future__ import annotations

import argparse
import fcntl
import logging
import os
import random
import signal
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ipc_server import IpcServer
from library import Library
from playlists import Favorites, PlaylistStore
from player import Player
import util

log = logging.getLogger("musicplayerd")


def build_song_view(library: Library, sid: str) -> dict | None:
    song = library.get(sid)
    if not song:
        return None
    s = dict(song)
    s["art_url"] = library.art_url(sid)
    return s


def resolve_playlist_ids(playlist: dict, library: Library) -> list[str]:
    """A playlist stores {id, path, title, artist} snapshots. If the
    library still has that id, use it; otherwise, mark it missing in
    the returned metadata (the GUI can gray it out) but keep the entry
    out of the *playable* id list."""
    ids = []
    for entry in playlist.get("songs", []):
        if library.get(entry["id"]):
            ids.append(entry["id"])
    return ids


class Daemon:
    def __init__(self, music_dir: Path, enable_mpris: bool = True):
        self.library = Library(music_dir)
        self.playlists = PlaylistStore()
        self.favorites = Favorites()
        self.player = Player(self.library)
        self.enable_mpris = enable_mpris
        self.mpris = None
        self.ipc: IpcServer | None = None

        self.player.on_change(self._on_player_change)

    # ------------------------------------------------------------------
    def _on_player_change(self, reason: str):
        if self.mpris is not None:
            try:
                self.mpris.notify(reason)
            except Exception:
                log.exception("mpris notify failed")
        if self.ipc is not None:
            state = self.player.get_state()
            if reason == "position":
                self.ipc.broadcaster.broadcast("position", {
                    "position": state["position"], "duration": state["duration"],
                })
            else:
                self.ipc.broadcaster.broadcast("state", self._public_state())

    def _public_state(self) -> dict:
        state = self.player.get_state()
        cur_id = state["current"]["id"] if state["current"] else None
        state["favorite"] = self.favorites.is_favorite(cur_id) if cur_id else False
        return state

    def snapshot(self) -> dict:
        return {
            "state": self._public_state(),
            "library": self.library.as_list(),
            "playlists": self.playlists.all_playlists(),
            "favorites": self.favorites.list_ids(),
        }

    # ------------------------------------------------------------------
    # command handlers -- names match the "cmd" field clients send
    # ------------------------------------------------------------------
    def build_handlers(self) -> dict:
        return {
            "get_state": lambda m: self._public_state(),
            "get_library": lambda m: self.library.as_list(),
            "get_playlists": lambda m: self.playlists.all_playlists(),
            "get_favorites": lambda m: self.favorites.list_ids(),

            "play": lambda m: self.player.play() or self._public_state(),
            "pause": lambda m: self.player.pause() or self._public_state(),
            "play_pause": lambda m: self.player.play_pause() or self._public_state(),
            "stop": lambda m: self.player.stop() or self._public_state(),
            "next": lambda m: self.player.next() or self._public_state(),
            "previous": lambda m: self.player.previous() or self._public_state(),
            "seek": lambda m: self.player.set_position(float(m["position"])) or self._public_state(),
            "seek_relative": lambda m: self.player.seek_relative(float(m["delta"])) or self._public_state(),
            "set_volume": lambda m: self.player.set_volume(float(m["volume"])) or self._public_state(),
            "set_shuffle": lambda m: self.player.set_shuffle(bool(m["enabled"])) or self._public_state(),
            "set_repeat": lambda m: self.player.set_repeat(str(m["mode"])) or self._public_state(),

            "play_song": self._cmd_play_song,
            "play_queue": self._cmd_play_queue,
            "play_all": self._cmd_play_all,
            "play_playlist": self._cmd_play_playlist,
            "play_favorites": self._cmd_play_favorites,

            "toggle_favorite": self._cmd_toggle_favorite,

            "create_playlist": lambda m: self._after_playlists(self.playlists.create(m["name"])),
            "delete_playlist": lambda m: self._after_playlists(self.playlists.delete(m["name"])),
            "rename_playlist": lambda m: self._after_playlists(self.playlists.rename(m["old"], m["new"])),
            "add_to_playlist": self._cmd_add_to_playlist,
            "remove_from_playlist": lambda m: self._after_playlists(
                self.playlists.remove_song(m["name"], m["id"])),
            "reorder_playlist": lambda m: self._after_playlists(
                self.playlists.reorder(m["name"], m["ids"])),

            "rescan_library": self._cmd_rescan,
        }

    def _after_playlists(self, _result):
        if self.ipc:
            self.ipc.broadcaster.broadcast("playlists", self.playlists.all_playlists())
        return self.playlists.all_playlists()

    def _cmd_add_to_playlist(self, m):
        song = self.library.get(m["id"])
        if not song:
            raise ValueError("unknown song id")
        return self._after_playlists(self.playlists.add_song(m["name"], song))

    def _cmd_play_song(self, m):
        """Plays a single song picked from the library view. Queues the
        rest of the (currently sorted/displayed) library after it, so
        Next/Previous behave sensibly instead of just stopping."""
        sid = m["id"]
        if not self.library.get(sid):
            raise ValueError("unknown song id")
        ordered = [s["id"] for s in self.library.as_list()]
        start_index = ordered.index(sid) if sid in ordered else 0
        self.player.play_ids(ordered, start_index=start_index, shuffle=False,
                              source={"type": "library", "name": "All Songs"})
        return self._public_state()

    def _cmd_play_queue(self, m):
        ids = list(m["ids"])
        index = int(m.get("index", 0))
        shuffle = bool(m.get("shuffle", False))
        self.player.play_ids(ids, start_index=index, shuffle=shuffle,
                              source={"type": "queue", "name": None})
        return self._public_state()

    def _cmd_play_all(self, m):
        shuffle = bool(m.get("shuffle", False))
        ids = self.library.all_ids()
        start = random.randrange(len(ids)) if shuffle and ids else 0
        self.player.play_ids(ids, start_index=start, shuffle=shuffle,
                              source={"type": "library", "name": "All Songs"})
        return self._public_state()

    def _cmd_play_playlist(self, m):
        name = m["name"]
        shuffle = bool(m.get("shuffle", False))
        playlist = self.playlists.load(name)
        if not playlist:
            raise ValueError("unknown playlist")
        ids = resolve_playlist_ids(playlist, self.library)
        if not ids:
            raise ValueError("playlist has no playable songs")
        start_index = int(m.get("index", 0))
        self.player.play_ids(ids, start_index=start_index, shuffle=shuffle,
                              source={"type": "playlist", "name": name})
        return self._public_state()

    def _cmd_play_favorites(self, m):
        shuffle = bool(m.get("shuffle", False))
        ids = [i for i in self.favorites.list_ids() if self.library.get(i)]
        if not ids:
            raise ValueError("no favorites yet")
        start = random.randrange(len(ids)) if shuffle else 0
        self.player.play_ids(ids, start_index=start, shuffle=shuffle,
                              source={"type": "favorites", "name": "Favorites"})
        return self._public_state()

    def _cmd_toggle_favorite(self, m):
        sid = m["id"]
        new_state = self.favorites.toggle(sid)
        if self.ipc:
            self.ipc.broadcaster.broadcast("favorites", self.favorites.list_ids())
            self.ipc.broadcaster.broadcast("state", self._public_state())
        return {"id": sid, "favorite": new_state}

    def _cmd_rescan(self, m):
        full = bool(m.get("full", False))
        count = self.library.rescan(full=full)
        if self.ipc:
            self.ipc.broadcaster.broadcast("library", self.library.as_list())
        return {"count": count}

    # ------------------------------------------------------------------
    def start(self):
        log.info("Scanning music library at %s ...", self.library.music_root)
        self.library.rescan()
        log.info("Found %d songs", len(self.library.songs))

        if self.enable_mpris:
            try:
                from mpris import MprisService
                self.mpris = MprisService(self.player)
                self.mpris.start()
            except Exception as e:
                log.warning("MPRIS support disabled: %s", e)
                self.mpris = None

        self.ipc = IpcServer(util.socket_path(), self.build_handlers(), self.snapshot)
        self.ipc.serve_forever_in_thread()
        log.info("IPC socket listening at %s", util.socket_path())

        threading.Thread(target=self._periodic_rescan, daemon=True).start()

    def _periodic_rescan(self, interval_seconds: int = 300):
        while True:
            time.sleep(interval_seconds)
            try:
                before = len(self.library.songs)
                self.library.rescan()
                after = len(self.library.songs)
                if before != after and self.ipc:
                    self.ipc.broadcaster.broadcast("library", self.library.as_list())
            except Exception:
                log.exception("periodic rescan failed")


def _acquire_singleton_lock() -> "int | None":
    """Best-effort: prevent two daemons from fighting over the same
    mpv/dbus name/socket. Returns an fd that must be kept open for the
    life of the process (or None if locking isn't available)."""
    lock_path = util.runtime_dir() / "daemon.lock"
    try:
        fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fd
    except OSError:
        print("Another instance of musicplayerd appears to be running "
              f"(lock held on {lock_path}). Exiting.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Quickshell music player daemon")
    parser.add_argument("--music-dir", default=None,
                         help="Directory to scan for music (default: ~/Music)")
    parser.add_argument("--no-mpris", action="store_true", help="Disable MPRIS/D-Bus integration")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
    )

    _acquire_singleton_lock()

    music_dir = Path(os.path.expanduser(args.music_dir)) if args.music_dir else util.music_dir()
    daemon = Daemon(music_dir, enable_mpris=not args.no_mpris)
    daemon.start()

    stop_event = threading.Event()

    def _handle_signal(signum, _frame):
        log.info("Received signal %s, shutting down", signum)
        stop_event.set()

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    try:
        while not stop_event.is_set():
            stop_event.wait(1.0)
    finally:
        daemon.player.quit()


if __name__ == "__main__":
    main()