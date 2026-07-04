// shell.qml - the entry point Quickshell loads for this config
// (`quickshell -c MusicPlayer`, once installed to
// ~/.config/quickshell/MusicPlayer). None of the files you had actually
// created a window or wired the Sidebar / pages / player controls
// together - this file is the missing piece that turns the components
// into a running app.
//
// NOTE: this uses Quickshell's FloatingWindow (a normal, decorated,
// resizable window) since this is a standalone app rather than a bar/
// panel. If your installed Quickshell version doesn't have
// FloatingWindow, check `quickshell --help` / the Quickshell docs for
// the equivalent in your version (older/newer releases have shuffled
// this API around) and swap it in here.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules

ShellRoot {
    FloatingWindow {
        id: window
        title: "Quickshell Music Player"
        implicitWidth: 960
        implicitHeight: 640

        color: Theme.background

        // ---- optional theme background image ----
        Image {
            anchors.fill: parent
            visible: Theme.backgroundImage.length > 0
            source: Theme.backgroundImage.length > 0 ? "file://" + Theme.backgroundImage : ""
            fillMode: Image.PreserveAspectCrop
            opacity: Theme.backgroundImageOpacity
            asynchronous: true
            layer.enabled: Theme.backgroundImageBlur
        }

        FocusScope {
            id: focusScope
            anchors.fill: parent
            focus: true

            // ---- global keybinds (see modules/Keybinds.qml) ----
            Keys.onPressed: (event) => {
                const action = Keybinds.actionFor(event)
                if (!action) return
                event.accepted = true
                switch (action) {
                    case "play_pause": Backend.playPause(); break
                    case "next": Backend.next(); break
                    case "previous": Backend.previous(); break
                    case "seek_forward": Backend.seekRelative(5); break
                    case "seek_backward": Backend.seekRelative(-5); break
                    case "volume_up": Backend.setVolume(Math.min(1.5, Backend.volume + 0.05)); break
                    case "volume_down": Backend.setVolume(Math.max(0, Backend.volume - 0.05)); break
                    case "toggle_shuffle": Backend.setShuffle(!Backend.shuffle); break
                    case "cycle_repeat": Backend.cycleRepeat(); break
                    case "toggle_favorite":
                        if (Backend.currentTrack) Backend.toggleFavorite(Backend.currentTrack.id)
                        break
                    // "focus_search" is left to each page's own search field
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: Theme.spacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.spacing

                    Sidebar {
                        id: sidebar
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        LibraryPage {
                            anchors.fill: parent
                            visible: sidebar.selected === "library"
                        }
                        FavoritesPage {
                            anchors.fill: parent
                            visible: sidebar.selected === "favorites"
                        }
                        PlaylistDetailPage {
                            anchors.fill: parent
                            visible: sidebar.selected.indexOf("playlist:") === 0
                            playlistName: sidebar.selected.indexOf("playlist:") === 0 ? sidebar.selected.slice("playlist:".length) : ""
                            onDeleted: sidebar.select("library")
                        }
                    }
                }

                PlayerBar {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
