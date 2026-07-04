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
5. Write `shell.qml`, `NavItem.qml`, `modules/qmldir`, and a transport bar
   component (the functional gaps listed in section 4).
6. Test manually: `quickshell -c MusicPlayer`.
7. Once it looks right, add the `.desktop` file + icon so it shows up in drun.

## Errors I have found

1. When clicking on the Play button, the music plays, but the Play button doesn't change to a pause button. Clicking Play again restarts the music, instead of pausing it. Very strange behavior.
2. When music is playing, although the time is accurately reflected in the WINDOW, my bar (which uses MPRIS) disagrees, and thinks that the music is paused at 0:00. However hitting the Play button on my bar
    - keeps my bar's and my window's buttons as Play buttons, and
    - restarts the music from the start
3. I added one song. The art, name, and author show up perfectly fine in the bottom playbar, but the element in the SongList (i think thats what its called; the list of songs in the main menu) has essentially no data:
    - It has a little music icon on the left, and on the right a black question mark and a white + button, and nothing else
    - the hover animation is a tad odd: it starts by highlighting in a darker color, then removes that and highlights a slightly larger area with more rounded corners in a lighter color
    - the same effect happens for the '?' and '+' on the right side, and the colors are the SAME, meaning that i can't see any highlight when im hovering them (except for like .2 seconds when i first hover where it goes darker for some reason)
4. Lots of errors thrown in the console when I do many actions, such as hitting Play, clicking on the song in the main menu, clicking on its +, or its ?, favoriting, or even hitting many keybinds: `WARN scene: @modules/SongList.qml[106:-1]: ReferenceError: modelData is not defined`
5. theres a few other errors, but iforget what threw them:
```
 quickshell -c MusicPlayer
  INFO: Launching config: "/home/hyperion/.config/quickshell/MusicPlayer/shell.qml"
  INFO: Shell ID: "98274392542cbc95048a26d3ba727b53" Path ID "98274392542cbc95048a26d3ba727b53"
  INFO: Saving logs to "/run/user/1000/quickshell/by-id/nt31bjlmht/log.qslog"
  INFO: Configuration Loaded
  WARN scene: @modules/SongRow.qml[45:-1]: TypeError: Cannot read property 'art_url' of undefined
  WARN scene: @modules/SongRow.qml[42:-1]: TypeError: Cannot read property 'art_url' of undefined
  WARN scene: @modules/SongRow.qml[49:-1]: TypeError: Cannot read property 'art_url' of undefined
  WARN scene: @modules/SongRow.qml[61:-1]: TypeError: Cannot read property 'title' of undefined
  WARN scene: @modules/SongRow.qml[69:-1]: TypeError: Cannot read property 'artist' of undefined
  WARN scene: @modules/SongRow.qml[77:-1]: TypeError: Cannot read property 'duration' of undefined
  WARN scene: @modules/SongRow.qml[86:-1]: TypeError: Cannot read property 'id' of undefined
  WARN scene: @modules/SongRow.qml[85:-1]: TypeError: Cannot read property 'id' of undefined
  WARN scene: @modules/SongList.qml[106:-1]: ReferenceError: modelData is not defined
  WARN scene: @modules/SongList.qml[105:-1]: ReferenceError: modelData is not defined
  WARN scene: @modules/SongList.qml[114:-1]: ReferenceError: modelData is not defined
  WARN scene: @modules/SongList.qml[111:-1]: ReferenceError: modelData is not defined
  WARN qml: Backend: command failed: playlist has no playable songs
  WARN qml: Backend: command failed: playlist has no playable songs
  WARN scene: @modules/SongList.qml[115:-1]: ReferenceError: modelData is not defined
  WARN scene: @modules/SongList.qml[111:-1]: ReferenceError: modelData is not defined
  WARN scene: @modules/Keybinds.qml[59:-1]: TypeError: Property 'onBindingsChanged' of object Keybinds_QMLTYPE_1(0x7fa67a996880) is not a function
```
6. some keybinds just silently fail, like searching
7. whatever the icon is in the very top right (next to a play button on the right) looks weird, it looks like a right harpoon, and has no discernable purpose
8. In the menu on the left, the padding on the left side of the menu is greater than that on the right side, and it makes it look a tad odd