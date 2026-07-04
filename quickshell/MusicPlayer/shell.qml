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
        // Wires up the previously-unused windowOpacity theme knob.
        // Whether this actually produces visible transparency depends
        // on your compositor - most Wayland/X11 compositors with
        // compositing enabled will honor it, some window managers won't.
        opacity: Theme.windowOpacity

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
            // Previously fontFamily was loaded from theme.json but never
            // applied anywhere, so it silently did nothing. Setting it
            // here lets every Text element below inherit it (QtQuick
            // cascades `font` down the item tree to children that don't
            // set their own family explicitly).
            font.family: Theme.fontFamily

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

            // ---- error toast --------------------------------------------------
            // Backend.errorReceived was already emitted whenever a command
            // failed, but nothing was ever connected to it, so failures
            // (bad IDs, unknown playlists, etc.) only ever showed up as a
            // console.warn - invisible unless you were watching the
            // terminal. This surfaces them in the UI instead.
            Connections {
                target: Backend
                function onErrorReceived(message) {
                    errorToast.text = message
                    errorToast.show()
                }
            }

            Rectangle {
                id: errorToast
                property alias text: toastText.text
                function show() {
                    opacity = 1
                    hideTimer.restart()
                }

                z: 1000
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 110
                radius: Theme.cornerRadius * 0.6
                color: Theme.danger
                opacity: 0
                visible: opacity > 0
                width: toastText.implicitWidth + 32
                height: toastText.implicitHeight + 18

                Behavior on opacity { NumberAnimation { duration: Theme.anim(200); easing.type: Theme.easingType() } }

                Text {
                    id: toastText
                    anchors.centerIn: parent
                    color: Theme.background
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                Timer { id: hideTimer; interval: 3500; onTriggered: errorToast.opacity = 0 }
            }
        }
    }
}
