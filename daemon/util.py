"""
util.py - shared helpers for the music player daemon.

Path handling, stable song IDs, and filename sanitizing live here.
Kept in one place because several other modules need the exact same
XDG paths and the exact same ID scheme.
"""
from __future__ import annotations

import hashlib
import os
import re
import unicodedata
from pathlib import Path

APP_NAME = "quickshell-musicplayer"


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    p = Path(base) / APP_NAME
    p.mkdir(parents=True, exist_ok=True)
    return p


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    p = Path(base) / APP_NAME
    p.mkdir(parents=True, exist_ok=True)
    return p


def art_cache_dir() -> Path:
    p = cache_dir() / "art"
    p.mkdir(parents=True, exist_ok=True)
    return p


def playlists_dir() -> Path:
    p = config_dir() / "playlists"
    p.mkdir(parents=True, exist_ok=True)
    return p


def runtime_dir() -> Path:
    """Where the IPC socket lives. Prefer XDG_RUNTIME_DIR (tmpfs, auto
    cleaned on logout); fall back to the cache dir if it isn't set."""
    base = os.environ.get("XDG_RUNTIME_DIR")
    if base:
        p = Path(base) / APP_NAME
    else:
        p = cache_dir() / "run"
    p.mkdir(parents=True, exist_ok=True)
    return p


def socket_path() -> Path:
    return runtime_dir() / "ipc.sock"


def music_dir() -> Path:
    # Respect XDG user dirs if set, otherwise default to ~/Music
    xdg = os.environ.get("XDG_MUSIC_DIR")
    if xdg:
        return Path(os.path.expanduser(xdg))
    return Path.home() / "Music"


def song_id(path: str) -> str:
    """Stable-ish ID for a song, derived from its absolute path.

    NOTE: if a file is moved or renamed, its ID changes. Playlists and
    favorites therefore also store the original path/title as a fallback
    so the UI can show a friendly "missing" placeholder instead of
    silently losing the entry -- see playlists.py.
    """
    ap = os.path.abspath(path)
    return hashlib.sha1(ap.encode("utf-8", errors="surrogateescape")).hexdigest()[:16]


_SLUG_RE = re.compile(r"[^a-zA-Z0-9._-]+")


def slugify(name: str, fallback: str = "playlist") -> str:
    """Turn an arbitrary, possibly-unicode, possibly-weird playlist name
    into a safe filename component.

    This is the important bit for the "strange characters could break
    something" warning: we NEVER use the raw song/playlist name as a
    file path directly. We normalize unicode, strip anything that isn't
    alphanumeric/dot/dash/underscore, collapse the rest to dashes, and
    fall back to a hash if nothing usable is left. The *display* name is
    always kept, verbatim and UTF-8 safe, inside the JSON file itself --
    only the on-disk filename is sanitized.
    """
    normalized = unicodedata.normalize("NFKD", name)
    ascii_ish = normalized.encode("ascii", "ignore").decode("ascii")
    slug = _SLUG_RE.sub("-", ascii_ish).strip("-._")
    slug = slug.lower()
    if not slug:
        slug = fallback + "-" + hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return slug[:80]


def unique_playlist_path(name: str) -> Path:
    base_slug = slugify(name)
    d = playlists_dir()
    candidate = d / f"{base_slug}.json"
    n = 2
    while candidate.exists():
        candidate = d / f"{base_slug}-{n}.json"
        n += 1
    return candidate


SUPPORTED_EXTS = {
    ".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".mp4",
    ".wav", ".wma", ".aac", ".ape", ".wv",
}