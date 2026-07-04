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
//
// SINGLE-INSTANCE / drun launch behaviour
// ----------------------------------------
// Previously the .desktop launcher ran `quickshell -c MusicPlayer`
// directly. Every launch from drun started a brand-new quickshell
// process, and none of them ever exited - `-n`/`--no-duplicate` just
// refuses to start a second one with an error, it doesn't bring the
// first one forward or let you "close" it and relaunch cleanly. The
// actual fix is to keep a single quickshell process running in the
// background and use Quickshell's own IPC mechanism (separate from
// musicplayerd's socket) to show/hide *its* window instead of ever
// spawning a second process. See the IpcHandler below and
// bin/quickshell-musicplayer-toggle.sh, which is what the .desktop
// entry now calls instead of `quickshell -c MusicPlayer` directly.
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

        // Wires up the previously-unused windowOpacity theme knob. FloatingWindow
        // is a window, not an Item, so it has no "opacity" property to assign -
        // the transparency has to live in the alpha channel of the window's own
        // background color instead. Whether this actually produces visible
        // transparency depends on your compositor - most Wayland/X11 compositors
        // with compositing enabled will honor it, some window managers won't.
        color: Qt.alpha(Theme.background, Theme.windowOpacity)

        // Closing the window (the WM's X button, Alt+F4, etc.) used to
        // quit the whole quickshell process outright, which is the
        // opposite of what you want for a single persistent instance
        // that the .desktop launcher toggles the visibility of. Now it
        // just hides the window; the process (and its connection to
        // musicplayerd) stays alive so re-opening from drun is instant
        // and the daemon-duplication problem above can't happen.
        onClosing: (close) => {
            close.accepted = false
            window.visible = false
        }

        // External show/hide/toggle control, called like:
        //   quickshell -c MusicPlayer ipc call window toggle
        // This is what lets a single already-running instance respond
        // to being "launched" again from a drun menu instead of a new
        // process spawning.
        IpcHandler {
            target: "window"
            function toggle(): void { window.visible = !window.visible }
            function show(): void { window.visible = true }
            function hide(): void { window.visible = false }
        }

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
            // NOTE: this used to be `font.family: Theme.fontFamily` here,
            // on the theory that QtQuick cascades `font` down the item
            // tree the way CSS cascades font-family. It doesn't: `font`
            // is only a real property on Text/TextInput/TextEdit and on
            // QtQuick Controls' `Control` (which propagates it to child
            // *Controls* only, never to plain Text items). FocusScope is
            // a plain Item, so it has no `font` property at all, which
            // is exactly the "Cannot assign to non-existent property
            // "font"" error - assigning to a property that isn't there.
            //
            // There's no shortcut around this in QtQuick: to actually
            // honor Theme.fontFamily, every Text/TextInput/TextField in
            // the app now sets `font.family: Theme.fontFamily` itself
            // (see Sidebar.qml, NavItem.qml, IconButton.qml, SongRow.qml,
            // SongList.qml, PlayerBar.qml, PlaylistDetailPage.qml, and
            // AddToPlaylistPopup.qml).

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
                    case "focus_search": {
                        // Forward to whichever page is actually visible.
                        // Each page exposes its own focusSearch() (see
                        // SongList.qml) - this was never actually called
                        // from anywhere, which is why the keybind quietly
                        // did nothing no matter how it was bound.
                        if (sidebar.selected === "library") {
                            libraryPage.focusSearch()
                        } else if (sidebar.selected === "favorites") {
                            favoritesPage.focusSearch()
                        } else if (sidebar.selected.indexOf("playlist:") === 0) {
                            playlistDetailPage.focusSearch()
                        }
                        break
                    }
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
                            id: libraryPage
                            anchors.fill: parent
                            visible: sidebar.selected === "library"
                        }
                        FavoritesPage {
                            id: favoritesPage
                            anchors.fill: parent
                            visible: sidebar.selected === "favorites"
                        }
                        PlaylistDetailPage {
                            id: playlistDetailPage
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
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                Timer { id: hideTimer; interval: 3500; onTriggered: errorToast.opacity = 0 }
            }
        }
    }
}
