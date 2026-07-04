"""
mpris.py - exposes the player over D-Bus as an MPRIS2 media player, so
bars/widgets (waybar, ago-gnome, GNOME shell, KDE plasma, playerctl,
etc.) can see and control it.

Implemented by hand against the MPRIS2 spec
(https://specifications.freedesktop.org/mpris-spec/2.2/) using
dbus-python + PyGObject's GLib main loop, rather than depending on a
third-party MPRIS-server wrapper library, since the spec itself is
small, extremely stable, and this way there is exactly one moving part
to debug if a bar doesn't pick the player up.

Requires the system packages providing `dbus-python` and `PyGObject`
(on Arch: python-dbus, python-gobject -- these bind to system D-Bus /
GLib libraries and generally should NOT be pip-installed into a venv).
"""
from __future__ import annotations

import logging
import threading

log = logging.getLogger("mpris")

try:
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
    MPRIS_AVAILABLE = True
except ImportError:  # pragma: no cover
    MPRIS_AVAILABLE = False
    GLib = None

BUS_NAME = "org.mpris.MediaPlayer2.quickshellmusicplayer"
OBJECT_PATH = "/org/mpris/MediaPlayer2"
IFACE_ROOT = "org.mpris.MediaPlayer2"
IFACE_PLAYER = "org.mpris.MediaPlayer2.Player"
IFACE_PROPS = "org.freedesktop.DBus.Properties"

_STATUS_MAP = {True: "Playing", False: "Paused"}


class MprisService:
    """Owns the GLib main loop thread and the D-Bus object. `player` is
    the player.Player instance; this class only translates between it
    and the MPRIS/D-Bus world."""

    def __init__(self, player, desktop_entry: str = "quickshell-musicplayer"):
        if not MPRIS_AVAILABLE:
            raise RuntimeError(
                "dbus-python / PyGObject not available. On Arch: "
                "pacman -S python-dbus python-gobject"
            )
        self.player = player
        self.desktop_entry = desktop_entry
        self._loop = None
        self._thread = None
        self._obj: "_MprisObject" = None

    def start(self):
        DBusGMainLoop(set_as_default=True)
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self):
        bus = dbus.SessionBus()
        bus_name = dbus.service.BusName(BUS_NAME, bus=bus)
        self._obj = _MprisObject(bus_name, self)
        self._loop = GLib.MainLoop()
        log.info("MPRIS service published as %s", BUS_NAME)
        try:
            self._loop.run()
        except Exception:
            log.exception("MPRIS main loop crashed")

    # called from any thread (player callbacks) -- marshal onto the
    # GLib loop before touching dbus objects.
    def notify(self, reason: str):
        if self._obj is None:
            return
        GLib.idle_add(self._obj.handle_change, reason)


def _metadata_for(player, library) -> dict:
    song = player.current_song()
    if not song:
        return {"mpris:trackid": dbus.ObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack")}
    length_us = dbus.Int64(int((song.get("duration") or 0) * 1_000_000))
    trackid = dbus.ObjectPath(f"/org/quickshellmusicplayer/track/{song['id']}")
    md = {
        "mpris:trackid": trackid,
        "mpris:length": length_us,
        "xesam:title": dbus.String(song.get("title") or ""),
        "xesam:album": dbus.String(song.get("album") or ""),
        "xesam:artist": dbus.Array([dbus.String(song.get("artist") or "")], signature="s"),
        "xesam:url": dbus.String("file://" + song.get("path", "")),
    }
    art = song.get("art_url")
    if art:
        md["mpris:artUrl"] = dbus.String(art)
    if song.get("track_no"):
        md["xesam:trackNumber"] = dbus.Int32(song["track_no"])
    return md


class _MprisObject(dbus.service.Object):
    def __init__(self, bus_name, service: MprisService):
        dbus.service.Object.__init__(self, bus_name, OBJECT_PATH)
        self.service = service
        self.player = service.player

    # ------------------------------------------------------------------
    # org.mpris.MediaPlayer2
    # ------------------------------------------------------------------
    @dbus.service.method(IFACE_ROOT)
    def Raise(self):
        pass  # no window-raising support required by the spec

    @dbus.service.method(IFACE_ROOT)
    def Quit(self):
        self.player.stop()

    # ------------------------------------------------------------------
    # org.mpris.MediaPlayer2.Player
    # ------------------------------------------------------------------
    @dbus.service.method(IFACE_PLAYER)
    def Next(self):
        self.player.next()

    @dbus.service.method(IFACE_PLAYER)
    def Previous(self):
        self.player.previous()

    @dbus.service.method(IFACE_PLAYER)
    def Pause(self):
        self.player.pause()

    @dbus.service.method(IFACE_PLAYER)
    def PlayPause(self):
        self.player.play_pause()

    @dbus.service.method(IFACE_PLAYER)
    def Stop(self):
        self.player.stop()

    @dbus.service.method(IFACE_PLAYER)
    def Play(self):
        self.player.play()

    @dbus.service.method(IFACE_PLAYER, in_signature="x")
    def Seek(self, offset_us):
        self.player.seek_relative(offset_us / 1_000_000.0)

    @dbus.service.method(IFACE_PLAYER, in_signature="ox")
    def SetPosition(self, track_id, position_us):
        self.player.set_position(position_us / 1_000_000.0)

    @dbus.service.method(IFACE_PLAYER, in_signature="s")
    def OpenUri(self, uri):
        pass  # not supported: this player only plays from the local library

    @dbus.service.signal(IFACE_PLAYER, signature="x")
    def Seeked(self, position_us):
        pass

    # ------------------------------------------------------------------
    # org.freedesktop.DBus.Properties
    # ------------------------------------------------------------------
    @dbus.service.method(IFACE_PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.GetAll(interface)[prop]

    @dbus.service.method(IFACE_PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface == IFACE_ROOT:
            return {
                "CanQuit": dbus.Boolean(True),
                "CanRaise": dbus.Boolean(False),
                "HasTrackList": dbus.Boolean(False),
                "Identity": dbus.String("Quickshell Music Player"),
                "DesktopEntry": dbus.String(self.service.desktop_entry),
                "SupportedUriSchemes": dbus.Array([], signature="s"),
                "SupportedMimeTypes": dbus.Array([], signature="s"),
            }
        if interface == IFACE_PLAYER:
            state = self.player.get_state()
            return {
                "PlaybackStatus": dbus.String(
                    "Stopped" if state["stopped"] else _STATUS_MAP[state["playing"]]
                ),
                "LoopStatus": dbus.String(
                    {"off": "None", "one": "Track", "all": "Playlist"}[state["repeat"]]
                ),
                "Rate": dbus.Double(1.0),
                "Shuffle": dbus.Boolean(state["shuffle"]),
                "Metadata": dbus.Dictionary(_metadata_for(self.player, self.player.library),
                                             signature="sv"),
                "Volume": dbus.Double(state["volume"]),
                "Position": dbus.Int64(int(state["position"] * 1_000_000)),
                "MinimumRate": dbus.Double(1.0),
                "MaximumRate": dbus.Double(1.0),
                "CanGoNext": dbus.Boolean(True),
                "CanGoPrevious": dbus.Boolean(True),
                "CanPlay": dbus.Boolean(True),
                "CanPause": dbus.Boolean(True),
                "CanSeek": dbus.Boolean(True),
                "CanControl": dbus.Boolean(True),
            }
        return {}

    @dbus.service.method(IFACE_PROPS, in_signature="ssv")
    def Set(self, interface, prop, value):
        if interface != IFACE_PLAYER:
            return
        if prop == "Volume":
            self.player.set_volume(float(value))
        elif prop == "LoopStatus":
            mode = {"None": "off", "Track": "one", "Playlist": "all"}.get(str(value), "off")
            self.player.set_repeat(mode)
        elif prop == "Shuffle":
            self.player.set_shuffle(bool(value))

    @dbus.service.signal(IFACE_PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed_properties, invalidated_properties):
        pass

    # ------------------------------------------------------------------
    # bridging from player.py's plain-python callback
    # ------------------------------------------------------------------
    def handle_change(self, reason: str):
        try:
            if reason == "position":
                # spec says Position is not a change-notified property;
                # emit Seeked instead so clients resync their scrubber.
                state = self.player.get_state()
                self.Seeked(dbus.Int64(int(state["position"] * 1_000_000)))
                return False
            props = self.GetAll(IFACE_PLAYER)
            changed = {k: v for k, v in props.items() if k != "Position"}
            self.PropertiesChanged(IFACE_PLAYER, dbus.Dictionary(changed, signature="sv"), [])
        except Exception:
            log.exception("Failed to emit MPRIS PropertiesChanged")
        return False  # tells GLib.idle_add not to repeat