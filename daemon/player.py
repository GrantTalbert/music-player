"""
player.py - the actual playback engine.

Wraps python-mpv (libmpv bindings) and layers queue / shuffle / repeat
/ favorites-aware playback on top of it. This module knows nothing
about D-Bus or sockets -- it just exposes plain Python callbacks
(`on_change`) that other modules subscribe to.
"""
from __future__ import annotations

import logging
import random
import threading
import time
from typing import Callable, Optional

log = logging.getLogger("player")

try:
    import mpv
except ImportError:  # pragma: no cover
    mpv = None

REPEAT_MODES = ("off", "one", "all")


class Player:
    def __init__(self, library):
        if mpv is None:
            raise RuntimeError(
                "python-mpv is not installed. Run: pip install --break-system-packages python-mpv "
                "(and make sure libmpv is installed, e.g. `pacman -S mpv`)."
            )
        self.library = library

        self._mpv = mpv.MPV(
            video=False,
            ytdl=False,
            input_default_bindings=False,
            input_vo_keyboard=False,
        )
        self._mpv.loop_file = False

        self.lock = threading.RLock()
        self.queue: list[str] = []          # ordered list of song ids currently queued
        self.queue_index: int = -1
        self.shuffle: bool = False
        self.repeat: str = "off"            # off | one | all
        self.source: dict = {"type": "none", "name": None}
        self._original_order: list[str] = []  # order before shuffling, for un-shuffle
        self._is_stopped = True

        self._listeners: list[Callable[[str], None]] = []

        self._mpv.observe_property("time-pos", self._on_time_pos)
        self._mpv.observe_property("pause", lambda name, val: self._notify("pause"))
        self._mpv.event_callback("end-file")(self._on_end_file)

        self._last_position_emit = 0.0

    # ------------------------------------------------------------------
    # subscription
    # ------------------------------------------------------------------
    def on_change(self, cb: Callable[[str], None]):
        self._listeners.append(cb)

    def _notify(self, reason: str):
        for cb in list(self._listeners):
            try:
                cb(reason)
            except Exception:
                log.exception("listener failed for %s", reason)

    def _on_time_pos(self, name, value):
        if value is None:
            return
        now = time.time()
        if now - self._last_position_emit > 0.9:
            self._last_position_emit = now
            self._notify("position")

    def _on_end_file(self, event):
        try:
            reason = event.get("event", {}).get("reason") if isinstance(event, dict) else None
        except Exception:
            reason = None
        # "eof" = natural end of track -> advance. anything else (user
        # initiated stop/switch) is handled by whoever called it.
        if reason == "eof":
            with self.lock:
                self._advance(auto=True)

    # ------------------------------------------------------------------
    # queue construction
    # ------------------------------------------------------------------
    def play_ids(self, ids: list[str], start_index: int = 0,
                 shuffle: bool = False, source: Optional[dict] = None):
        with self.lock:
            ids = [i for i in ids if self.library.get(i)]
            if not ids:
                return
            self._original_order = list(ids)
            self.shuffle = shuffle
            self.source = source or {"type": "custom", "name": None}

            if shuffle:
                start_id = ids[start_index] if 0 <= start_index < len(ids) else ids[0]
                rest = [i for i in ids if i != start_id]
                random.shuffle(rest)
                self.queue = [start_id] + rest
                self.queue_index = 0
            else:
                self.queue = list(ids)
                self.queue_index = max(0, min(start_index, len(ids) - 1))

            self._is_stopped = False
            self._load_current()

    def _load_current(self):
        if not (0 <= self.queue_index < len(self.queue)):
            return
        sid = self.queue[self.queue_index]
        song = self.library.get(sid)
        if not song:
            self._advance(auto=True)
            return
        self._mpv.play(song["path"])
        self._mpv.pause = False
        self._notify("track")

    # ------------------------------------------------------------------
    # transport controls
    # ------------------------------------------------------------------
    def play(self):
        with self.lock:
            if self._is_stopped and self.queue:
                self._load_current()
            else:
                self._mpv.pause = False
            self._notify("state")

    def pause(self):
        with self.lock:
            self._mpv.pause = True
            self._notify("state")

    def play_pause(self):
        with self.lock:
            if self._is_stopped:
                self.play()
                return
            self._mpv.pause = not bool(self._mpv.pause)
            self._notify("state")

    def stop(self):
        with self.lock:
            self._is_stopped = True
            try:
                self._mpv.stop()
            except Exception:
                pass
            self._notify("state")

    def next(self):
        with self.lock:
            self._advance(auto=False)

    def previous(self):
        with self.lock:
            pos = self._safe_time_pos()
            if pos is not None and pos > 3.0:
                # restart current track, like most players do
                self._mpv.seek(0, reference="absolute")
                self._notify("position")
                return
            if self.queue_index > 0:
                self.queue_index -= 1
                self._load_current()
            elif self.repeat == "all" and self.queue:
                self.queue_index = len(self.queue) - 1
                self._load_current()
            else:
                self._mpv.seek(0, reference="absolute")
                self._notify("position")

    def _advance(self, auto: bool):
        if not self.queue:
            self._is_stopped = True
            self._notify("state")
            return

        if auto and self.repeat == "one":
            self._load_current()
            return

        if self.queue_index + 1 < len(self.queue):
            self.queue_index += 1
            self._load_current()
            return

        if self.repeat == "all":
            if self.shuffle:
                current = self.queue[self.queue_index]
                rest = [i for i in self._original_order if i != current]
                random.shuffle(rest)
                self.queue = [current] + rest
            self.queue_index = 0
            self._load_current()
            return

        # end of queue, no repeat
        self._is_stopped = True
        try:
            self._mpv.pause = True
        except Exception:
            pass
        self._notify("state")

    def seek_relative(self, delta_seconds: float):
        with self.lock:
            try:
                self._mpv.seek(delta_seconds, reference="relative")
            except Exception:
                pass
            self._notify("position")

    def set_position(self, seconds: float):
        with self.lock:
            try:
                self._mpv.seek(max(0.0, seconds), reference="absolute")
            except Exception:
                pass
            self._notify("position")

    def set_volume(self, vol: float):
        """vol is 0.0 - 1.0 (mpris/UI scale); mpv wants 0-100."""
        with self.lock:
            vol = max(0.0, min(1.5, vol))
            self._mpv.volume = vol * 100.0
            self._notify("volume")

    def get_volume(self) -> float:
        try:
            return float(self._mpv.volume or 0.0) / 100.0
        except Exception:
            return 1.0

    def set_shuffle(self, enabled: bool):
        with self.lock:
            if enabled == self.shuffle:
                return
            self.shuffle = enabled
            if not self.queue:
                self._notify("state")
                return
            current = self.queue[self.queue_index] if 0 <= self.queue_index < len(self.queue) else None
            if enabled:
                rest = [i for i in self.queue[self.queue_index + 1:]]
                random.shuffle(rest)
                self.queue = self.queue[:self.queue_index + 1] + rest
            else:
                if current and current in self._original_order:
                    idx = self._original_order.index(current)
                    self.queue = list(self._original_order)
                    self.queue_index = idx
                else:
                    self.queue = list(self._original_order)
            self._notify("state")

    def set_repeat(self, mode: str):
        if mode not in REPEAT_MODES:
            return
        with self.lock:
            self.repeat = mode
            self._notify("state")

    # ------------------------------------------------------------------
    def _safe_time_pos(self) -> Optional[float]:
        try:
            return self._mpv.time_pos
        except Exception:
            return None

    def _safe_duration(self) -> Optional[float]:
        try:
            return self._mpv.duration
        except Exception:
            return None

    def current_song(self) -> Optional[dict]:
        if not (0 <= self.queue_index < len(self.queue)):
            return None
        sid = self.queue[self.queue_index]
        song = self.library.get(sid)
        if not song:
            return None
        s = dict(song)
        s["art_url"] = self.library.art_url(sid)
        return s

    def get_state(self) -> dict:
        with self.lock:
            song = self.current_song()
            playing = False
            try:
                playing = (not self._is_stopped) and (not bool(self._mpv.pause))
            except Exception:
                pass
            return {
                "playing": playing,
                "stopped": self._is_stopped,
                "current": song,
                "position": self._safe_time_pos() or 0.0,
                "duration": self._safe_duration() or (song.get("duration") if song else 0.0) or 0.0,
                "volume": self.get_volume(),
                "shuffle": self.shuffle,
                "repeat": self.repeat,
                "queue_index": self.queue_index,
                "queue_length": len(self.queue),
                "queue": self.queue,
                "source": self.source,
            }

    def quit(self):
        try:
            self._mpv.terminate()
        except Exception:
            pass