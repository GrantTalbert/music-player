# music player

a vibecoded music player build for me

not intended for public use, hence it being a vibecoded project built in like a day, and not something i put actual effort into

please do not download

built with assistance of Anthropic's *Claude* and Google's *Gemini*

the rest of this README.md is just incase you for some reason decide to download

## info

its an MPRIS music player which means that the information for the current playing song and what not can be accessed pretty easily by things with MPRIS integration. it also has a GUI constructed using Quickshell which is reasonably configureable. there are two user-maintained config files: `keybinds.json` and `theme.json`, both located at `~/.config/quickshell-musicplayer`. The `keybinds.json` file manages keybinds you can set to perform a few actions. The actions themselves should be fairly self-explanatory. Here is an example config
```json
{
  "play_pause": "space",
  "next": "right",
  "previous": "left",
  "seek_forward": "l",
  "seek_backward": "h",
  "volume_up": "up",
  "volume_down": "down",
  "toggle_shuffle": "s",
  "cycle_repeat": "r",
  "toggle_favorite": "f",
  "focus_search": "slash"
}
```
The `theme.json` file manages a bunch of theme variables, which also should be fairly self-explanatory. Here is an example config. Note that it supports background images; to not pass a background image, just leave `"backgroundImage": ""`. If you want a background image, pass the full path to that background image. The `appName` field controls the text in the top left of the app.
```json
{
  "background": "#1a1b26",
  "surface": "#20222f",
  "surfaceAlt": "#282a3a",
  "accent": "#7aa2f7",
  "accentAlt": "#bb9af7",
  "text": "#c0caf5",
  "textMuted": "#565f89",
  "danger": "#f7768e",
  "favoriteColor": "#f7768e",

  "cornerRadius": 14,
  "controlRadius": 999,
  "windowOpacity": 0.96,
  "surfaceOpacity": 0.85,
  "blurRadius": 24,

  "animationsEnabled": true,
  "animationDuration": 180,
  "animationEasing": "OutCubic",

  "backgroundImage": "/path/to/image",
  "backgroundImageOpacity": 0.35,
  "backgroundImageBlur": true,

  "fontFamily": "sans-serif",
  "fontSizeSmall": 11,
  "fontSizeNormal": 13,
  "fontSizeLarge": 16,
  "fontSizeHuge": 22,

  "spacing": 10,
  "padding": 16,

  "showArtwork": true,
  "compactRows": false,

  "appName": "Quickshell Music"
}
```

## usage

it pulls music files from `~/Music`, but you can override by starting the daemon with `--music-dir`. It can find music files in subfolders thereof. If you add a music file while the app is open, you need to press the refresh button next to where it says "Connected".

you can close the app while music is playing -- it spawns a python-based daemon which manages music playing. If you want to kill the daemon, run 

# setup

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
# this works for arch
sudo pacman -S mpv python-dbus python-gobject python-mpv python-mutagen
```

`python-dbus` / `python-gobject` are optional — if missing, MPRIS support
is silently disabled (logged as a warning) rather than crashing.

### Run it

```bash
python daemon/musicplayerd.py -v
```

By default it scans `~/Music` (override with `--music-dir`, or set
`XDG_MUSIC_DIR`).

The daemon should auto-start if it is not already running when you try to play music from the app. However, if it fails, you can set a systemd `--user` unit, e.g. `~/.config/systemd/user/musicplayerd.service`:

```ini
[Unit]
Description=Quickshell music player daemon

[Service]
ExecStart=/usr/bin/python /path/to/daemon/musicplayerd.py
Restart=on-failure

[Install]
WantedBy=default.target
```
Then run

```bash
systemctl --user enable --now musicplayerd.service
```
on startup.

---

## 2. Where the QML files go

Move the `MusicPlayer` folder into `~/.config/quickshell`:

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

## 4. getting it to open with drun/app menu

The app ships with an `icon.svg` and `quickshell-musicplayer-toggle.sh`. The former is the icon for the app that u see when u use drun to open it, so you can change that if you want then place it wherever. The latter is the script used for opening the GUI, so u can put that wherever. Then create a desktop entry
```
[Desktop Entry]
Type=Application
Name=music player owo
Comment=a local music player with mpris support
Exec=/path/to/quickshell-musicplayer-toggle.sh
Icon=/path/to/icon.svg
Terminal=false
Categories=AudioVide;Audio
```
Put this in a file `~/.local/share/applications/quickshell-musicplayer.desktop`. now it should open with drun

## 5. Launch checklist

1. Install system dependencies for the daemon.
2. Start (or `systemctl --user enable --now`) `musicplayerd`.
3. Place the QML files per the layout above.
4. Create a desktop entry
5. run the thing