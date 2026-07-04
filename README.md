# music player

a vibecoded music player build for me

not intended for public use, hence it being a vibecoded project and not something i put actual effort into

please do not download

# Quickshell Music Player — Setup Guide

This project has two halves that talk to each other over a unix socket:

1. **`musicplayerd`** — a Python daemon that owns `mpv`, scans your music
   library, persists playlists/favorites, and (optionally) publishes an
   MPRIS2 D-Bus interface.
2. **The Quickshell GUI** — a QML frontend that connects to the daemon's
   socket and renders everything.

They are independent processes. The daemon must be running *before* the
GUI is useful (the GUI just retries the connection every 2s if it isn't).

---

## 1. Where the daemon files go

All of these need to sit together in one flat folder (they import each
other by bare module name, e.g. `from util import ...`), but the folder
itself can live anywhere you like, e.g. `~/.local/share/quickshell-musicplayer/daemon/`:

```
daemon/
├── musicplayerd.py   # entry point
├── ipc_server.py
├── library.py
├── player.py
├── playlists.py
├── mpris.py
├── util.py
└── requirements.txt
```

### Install dependencies

```bash
# system packages (Arch example — adjust for your distro)
sudo pacman -S mpv python-dbus python-gobject

# python packages
pip install --break-system-packages -r daemon/requirements.txt
```

`python-dbus` / `python-gobject` are optional — if missing, MPRIS support
is silently disabled (logged as a warning) rather than crashing.

### Run it

```bash
python daemon/musicplayerd.py -v
```

By default it scans `~/Music` (override with `--music-dir`, or set
`XDG_MUSIC_DIR`). It opens its control socket at:

```
$XDG_RUNTIME_DIR/quickshell-musicplayer/ipc.sock
```

(or `~/.cache/quickshell-musicplayer/run/ipc.sock` if `XDG_RUNTIME_DIR`
isn't set) — this matches exactly what the GUI's `Backend.qml` looks for,
so don't change one without the other.

### Keep it running

Nothing currently auto-starts the daemon. Recommended: a systemd
`--user` unit, e.g. `~/.config/systemd/user/musicplayerd.service`:

```ini
[Unit]
Description=Quickshell music player daemon

[Service]
ExecStart=/usr/bin/python /path/to/daemon/musicplayerd.py
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now musicplayerd.service
```

---

## 2. Where the QML files go

Quickshell loads a *named* config directory: running `quickshell -c MusicPlayer`
looks in `~/.config/quickshell/MusicPlayer/`. Inside your shell config,
`qs` refers to that root, so every file that only does `import qs.modules`
must physically live under a `modules/` subfolder — that's how `Theme`,
`Backend`, `Keybinds`, `SongList`, `IconButton`, etc. resolve as bare
identifiers everywhere else.

**Target layout:**

```
~/.config/quickshell/MusicPlayer/
├── shell.qml
├── Sidebar.qml
├── LibraryPage.qml
├── FavoritesPage.qml
├── PlaylistDetailPage.qml
└── modules/
    ├── qmldir
    ├── Backend.qml
    ├── Theme.qml
    ├── Keybinds.qml
    ├── IconButton.qml
    ├── SongRow.qml
    ├── SongList.qml
    ├── AddToPlaylistPopup.qml
    └── NavItem.qml
```

---

## 3. Config files (theme / keybinds / playlists)

These live under `~/.config/quickshell-musicplayer/` (a *different*
directory from the Quickshell shell config — this one is shared between
the daemon and the GUI):

| File | Written by | Notes |
|---|---|---|
| `theme.json` | you | Optional — `Theme.qml` falls back to built-in dark defaults if absent. Supports `backgroundImage` for a custom wallpaper. |
| `keybinds.json` | you | Optional — `Keybinds.qml` falls back to built-in defaults (Space, arrows, etc.) if absent. |
| `playlists/*.json` | daemon, automatically | Created as you make playlists. |
| `favorites.json` | daemon, automatically | Created the first time you favorite a song. |

---

## 4. Launch checklist

1. Install system + pip dependencies for the daemon.
2. Start (or `systemctl --user enable --now`) `musicplayerd`.
3. Confirm the socket exists: `ls $XDG_RUNTIME_DIR/quickshell-musicplayer/`.
4. Place the QML files per the layout above.
5. Test manually: `quickshell -c MusicPlayer`.