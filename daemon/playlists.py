"""
playlists.py - persistence for user playlists and favorites.

IMPORTANT (see the project README): song titles, artist names, and
filenames can contain almost any unicode character, including quotes,
slashes, emoji, RTL text, null-adjacent weirdness, etc. To stay safe:

  * We NEVER use a song/playlist's display name as an on-disk path
    component directly -- see util.slugify().
  * All JSON is written with ensure_ascii=False + explicit utf-8
    encoding, so names round-trip exactly.
  * Playlist entries store {id, path, title, artist} rather than just
    an id, so if a file is later moved/renamed (which changes its id,
    see util.song_id) the playlist can still show a friendly "missing"
    row instead of silently vanishing or crashing.
  * Writes are atomic (write to temp file, then os.replace) so a crash
    or power loss mid-write can't corrupt a playlist file.
"""
from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import Optional

from util import config_dir, playlists_dir, slugify, unique_playlist_path

log = logging.getLogger("playlists")

FAVORITES_FILE = config_dir() / "favorites.json"


def _atomic_write_json(path: Path, data: dict):
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


class PlaylistStore:
    """Manages every *.json file under playlists_dir()."""

    def list_names(self) -> list[str]:
        names = []
        for p in sorted(playlists_dir().glob("*.json")):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                names.append(data.get("name", p.stem))
            except Exception as e:
                log.warning("Skipping unreadable playlist %s: %s", p, e)
        return names

    def _find_path(self, name: str) -> Optional[Path]:
        for p in playlists_dir().glob("*.json"):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if data.get("name") == name:
                    return p
            except Exception:
                continue
        return None

    def all_playlists(self) -> list[dict]:
        out = []
        for p in sorted(playlists_dir().glob("*.json")):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    out.append(json.load(f))
            except Exception as e:
                log.warning("Skipping unreadable playlist %s: %s", p, e)
        return out

    def load(self, name: str) -> Optional[dict]:
        p = self._find_path(name)
        if not p:
            return None
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)

    def create(self, name: str) -> dict:
        name = name.strip() or "Untitled Playlist"
        if self._find_path(name):
            raise ValueError(f"Playlist '{name}' already exists")
        path = unique_playlist_path(name)
        data = {"name": name, "created": time.time(), "songs": []}
        _atomic_write_json(path, data)
        return data

    def delete(self, name: str) -> bool:
        p = self._find_path(name)
        if not p:
            return False
        p.unlink(missing_ok=True)
        return True

    def rename(self, old: str, new: str) -> bool:
        p = self._find_path(old)
        if not p:
            return False
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        data["name"] = new
        _atomic_write_json(p, data)
        return True

    def add_song(self, name: str, song: dict) -> Optional[dict]:
        p = self._find_path(name)
        if not p:
            return None
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        entry = {
            "id": song["id"],
            "path": song["path"],
            "title": song.get("title", ""),
            "artist": song.get("artist", ""),
        }
        if not any(s["id"] == entry["id"] for s in data["songs"]):
            data["songs"].append(entry)
            _atomic_write_json(p, data)
        return data

    def remove_song(self, name: str, song_id: str) -> Optional[dict]:
        p = self._find_path(name)
        if not p:
            return None
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        data["songs"] = [s for s in data["songs"] if s["id"] != song_id]
        _atomic_write_json(p, data)
        return data

    def reorder(self, name: str, ordered_ids: list[str]) -> Optional[dict]:
        p = self._find_path(name)
        if not p:
            return None
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        by_id = {s["id"]: s for s in data["songs"]}
        new_songs = [by_id[i] for i in ordered_ids if i in by_id]
        # append anything that got missed so nothing is silently dropped
        for s in data["songs"]:
            if s["id"] not in ordered_ids:
                new_songs.append(s)
        data["songs"] = new_songs
        _atomic_write_json(p, data)
        return data


class Favorites:
    """Ordered list of favorited song ids, in the order they were
    favorited (oldest first) -- used for "play favorites in order"."""

    def __init__(self):
        self.order: list[str] = []
        self._load()

    def _load(self):
        if FAVORITES_FILE.exists():
            try:
                with open(FAVORITES_FILE, "r", encoding="utf-8") as f:
                    self.order = json.load(f).get("order", [])
            except Exception as e:
                log.warning("Failed to load favorites: %s", e)
                self.order = []

    def _save(self):
        _atomic_write_json(FAVORITES_FILE, {"order": self.order})

    def is_favorite(self, song_id: str) -> bool:
        return song_id in self.order

    def toggle(self, song_id: str) -> bool:
        """Returns the new favorite state."""
        if song_id in self.order:
            self.order.remove(song_id)
            self._save()
            return False
        self.order.append(song_id)
        self._save()
        return True

    def list_ids(self) -> list[str]:
        return list(self.order)