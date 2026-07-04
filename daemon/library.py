"""
library.py - scans the music directory, extracts metadata + cover art,
and caches the result to disk so subsequent launches are fast.
"""
from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import Optional

from util import SUPPORTED_EXTS, art_cache_dir, cache_dir, song_id

log = logging.getLogger("library")

try:
    import mutagen
    from mutagen import File as MutagenFile
except ImportError:  # pragma: no cover
    mutagen = None
    MutagenFile = None

LIBRARY_CACHE_FILE = cache_dir() / "library.json"

# Common "cover file sitting next to the track" names, checked as a
# fallback when a file has no embedded art.
_FOLDER_ART_NAMES = [
    "cover.jpg", "cover.jpeg", "cover.png",
    "folder.jpg", "folder.jpeg", "folder.png",
    "front.jpg", "front.jpeg", "front.png",
    "albumart.jpg", "albumart.png",
]


class Library:
    def __init__(self, music_root: Path):
        self.music_root = music_root
        self.songs: dict[str, dict] = {}  # id -> song dict
        self._load_cache()

    # ------------------------------------------------------------------
    # persistence
    # ------------------------------------------------------------------
    def _load_cache(self):
        if LIBRARY_CACHE_FILE.exists():
            try:
                with open(LIBRARY_CACHE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.songs = data.get("songs", {})
                log.info("Loaded %d cached songs", len(self.songs))
            except Exception as e:
                log.warning("Failed to load library cache: %s", e)
                self.songs = {}

    def _save_cache(self):
        tmp = LIBRARY_CACHE_FILE.with_suffix(".json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"songs": self.songs, "scanned_at": time.time()}, f,
                      ensure_ascii=False, indent=2)
        os.replace(tmp, LIBRARY_CACHE_FILE)

    # ------------------------------------------------------------------
    # scanning
    # ------------------------------------------------------------------
    def rescan(self, full: bool = False) -> int:
        """Walk music_root, add new/changed files, drop missing ones.
        Returns number of songs after the rescan."""
        if not self.music_root.exists():
            log.warning("Music directory %s does not exist", self.music_root)
            self.songs = {}
            self._save_cache()
            return 0

        seen_ids: set[str] = set()
        by_path = {v["path"]: (k, v) for k, v in self.songs.items()}

        for root, _dirs, files in os.walk(self.music_root):
            for fname in files:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in SUPPORTED_EXTS:
                    continue
                fpath = os.path.join(root, fname)
                try:
                    mtime = os.path.getmtime(fpath)
                except OSError:
                    continue

                existing = by_path.get(fpath)
                if existing and not full and existing[1].get("mtime") == mtime:
                    seen_ids.add(existing[0])
                    continue

                song = self._read_song(fpath, mtime)
                if song:
                    self.songs[song["id"]] = song
                    seen_ids.add(song["id"])

        # drop entries whose file disappeared
        removed = [sid for sid in self.songs if sid not in seen_ids]
        for sid in removed:
            del self.songs[sid]

        self._save_cache()
        log.info("Rescan complete: %d songs (%d removed)", len(self.songs), len(removed))
        return len(self.songs)

    def _read_song(self, fpath: str, mtime: float) -> Optional[dict]:
        sid = song_id(fpath)
        title = artist = album = None
        duration = 0.0
        track_no = None
        genre = None

        if MutagenFile is not None:
            try:
                easy = MutagenFile(fpath, easy=True)
                if easy is not None:
                    title = _first(easy.tags, "title") if easy.tags else None
                    artist = _first(easy.tags, "artist") if easy.tags else None
                    album = _first(easy.tags, "album") if easy.tags else None
                    genre = _first(easy.tags, "genre") if easy.tags else None
                    tno = _first(easy.tags, "tracknumber") if easy.tags else None
                    if tno:
                        try:
                            track_no = int(str(tno).split("/")[0])
                        except ValueError:
                            track_no = None
                    if easy.info is not None:
                        duration = float(getattr(easy.info, "length", 0.0) or 0.0)
            except Exception as e:
                log.debug("mutagen easy read failed for %s: %s", fpath, e)

        if not title:
            title = Path(fpath).stem

        has_art = self._ensure_art(fpath, sid)

        return {
            "id": sid,
            "path": fpath,
            "title": title,
            "artist": artist or "Unknown Artist",
            "album": album or "Unknown Album",
            "genre": genre or "",
            "duration": duration,
            "track_no": track_no,
            "has_art": has_art,
            "mtime": mtime,
        }

    # ------------------------------------------------------------------
    # cover art
    # ------------------------------------------------------------------
    def _ensure_art(self, fpath: str, sid: str) -> bool:
        """Extracts art to the art cache dir if not already there.
        Returns True if art is available (cached now or previously)."""
        art_path = art_cache_dir() / f"{sid}.jpg"
        if art_path.exists():
            return True

        data = self._extract_embedded_art(fpath)
        if data is None:
            data = self._find_folder_art(fpath)

        if data is None:
            return False

        try:
            with open(art_path, "wb") as f:
                f.write(data)
            return True
        except OSError as e:
            log.debug("Failed writing art cache for %s: %s", fpath, e)
            return False

    def _extract_embedded_art(self, fpath: str) -> Optional[bytes]:
        if MutagenFile is None:
            return None
        try:
            audio = MutagenFile(fpath)
        except Exception:
            return None
        if audio is None:
            return None

        try:
            # MP3 / ID3
            if hasattr(audio, "tags") and audio.tags is not None:
                for key in audio.tags.keys() if hasattr(audio.tags, "keys") else []:
                    if str(key).startswith("APIC"):
                        return audio.tags[key].data
            # FLAC / OGG (vorbis picture blocks)
            if hasattr(audio, "pictures") and audio.pictures:
                return audio.pictures[0].data
            # MP4 / M4A
            if hasattr(audio, "tags") and audio.tags is not None and "covr" in audio.tags:
                covr = audio.tags["covr"]
                if covr:
                    return bytes(covr[0])
        except Exception as e:
            log.debug("Embedded art extraction failed for %s: %s", fpath, e)
        return None

    def _find_folder_art(self, fpath: str) -> Optional[bytes]:
        folder = os.path.dirname(fpath)
        for name in _FOLDER_ART_NAMES:
            candidate = os.path.join(folder, name)
            if os.path.isfile(candidate):
                try:
                    with open(candidate, "rb") as f:
                        return f.read()
                except OSError:
                    continue
        return None

    # ------------------------------------------------------------------
    def get(self, sid: str) -> Optional[dict]:
        return self.songs.get(sid)

    def all_ids(self) -> list[str]:
        return list(self.songs.keys())

    def art_url(self, sid: str) -> str:
        p = art_cache_dir() / f"{sid}.jpg"
        return f"file://{p}" if p.exists() else ""

    def as_list(self) -> list[dict]:
        out = []
        for sid, song in self.songs.items():
            s = dict(song)
            s["art_url"] = self.art_url(sid)
            out.append(s)
        out.sort(key=lambda s: (s["artist"].lower(), s["album"].lower(),
                                 s.get("track_no") or 0, s["title"].lower()))
        return out


def _first(tags, key) -> Optional[str]:
    try:
        v = tags.get(key)
    except Exception:
        return None
    if not v:
        return None
    if isinstance(v, list):
        return str(v[0]) if v else None
    return str(v)