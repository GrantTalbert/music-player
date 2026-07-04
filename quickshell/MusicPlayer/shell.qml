// shell.qml - the entry point Quickshell loads for this config
// (`quickshell -c MusicPlayer`, once installed to
// ~/.config/quickshell/MusicPlayer).
//
// SINGLE-INSTANCE / drun launch behaviour
// ----------------------------------------
// The .desktop launcher runs quickshell-musicplayer-toggle.sh, which
// calls `quickshell -c MusicPlayer ipc call window makeVisible` and only
// falls back to spawning a brand new quickshell process if that IPC
// call fails (i.e. no instance is running yet). That means the
// IpcHandler below has to keep responding correctly for the entire
// life of the quickshell process.
//
// WHY THIS ISN'T JUST "onClosing: close.accepted = false"
// ----------------------------------------------------------
// QtQuick's own Window type has a cancelable `closing(CloseEvent)`
// signal you can veto. Quickshell's window types (FloatingWindow,
// PanelWindow, ...) do NOT have that - the only related signal is
// QsWindow.closed(), which is a one-way notification fired *after*
// the OS has already destroyed the window. There's nothing to accept/reject.
//
// Since the window is already gone by the time we find out about it,
// the fix is to rebuild it immediately via a Loader when requested, and 
// to keep the IpcHandler declared *outside* the loaded window (as a sibling)
// so it keeps working no matter how the previous window instance went away.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules

ShellRoot {
    id: root

    // Keeps this quickshell process alive after the music player window
    // is closed. Qt's QGuiApplication quits the ENTIRE process (not just
    // the window) when its last remaining window closes -
    // quitOnLastWindowClosed defaults to true, and this app was never
    // setting it otherwise. FloatingWindow is a real xdg-toplevel, which
    // is exactly what Hyprland's killactive (and the titlebar X) destroy
    // - and since it was the only window this process had, destroying it
    // took the whole daemon down with it, IPC socket and all. 
    //
    // A layer-shell surface isn't an xdg-toplevel, so killactive/WM close
    // keybinds don't target it, and it never gets destroyed - it just
    // needs to exist for Qt to consider the app as still having a window
    // open. 1x1, transparent, zero exclusive zone: invisible in practice.
    PanelWindow {
        anchors.top: true
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusiveZone: 0
    }

    Loader {
        id: windowLoader
        active: true
        sourceComponent: windowComponent
        onLoaded: {
            // Deferring the visibility toggle until after the object is fully seated
            // prevents the Wayland compositor from dropping the mapping request.
            Qt.callLater(() => {
                if (item) {
                    item.visible = true;
                }
            })
        }
    }

    // External show/hide/toggle control, called like:
    //   quickshell -c MusicPlayer ipc call window makeVisible
    // Lives at the ShellRoot level (not inside the window) so it keeps
    // responding even while windowLoader is rebuilding the window.
    IpcHandler {
        target: "window"
        
        function toggle(): void {
            if (windowLoader.active && windowLoader.item && windowLoader.item.visible) {
                hide()
            } else {
                makeVisible()
            }
        }
        
        function makeVisible(): void {
            if (!windowLoader.active) {
                // Creates the window. onLoaded will safely handle visibility.
                windowLoader.active = true
            } else if (windowLoader.item) {
                // Window exists but is hidden; just reveal it.
                windowLoader.item.visible = true
            }
        }
        
        function hide(): void {
            if (windowLoader.item) windowLoader.item.visible = false
        }
    }

    Component {
        id: windowComponent

        // NOTE: this uses Quickshell's FloatingWindow (a normal, decorated,
        // resizable window) since this is a standalone app rather than a bar/
        // panel. If your installed Quickshell version doesn't have
        // FloatingWindow, check `quickshell --help` / the Quickshell docs for
        // the equivalent in your version (older/newer releases have shuffled
        // this API around) and swap it in here.
        FloatingWindow {
            id: window
            title: "Quickshell Music Player"
            implicitWidth: 960
            implicitHeight: 640
            
            // Start hidden to prevent QtWayland from trying to map the 
            // surface at the exact millisecond of instantiation.
            visible: false

            // Wires up the previously-unused windowOpacity theme knob. FloatingWindow
            // is a window, not an Item, so it has no "opacity" property to assign -
            // the transparency has to live in the alpha channel of the window's own
            // background color instead. Whether this actually produces visible
            // transparency depends on your compositor - most Wayland/X11 compositors
            // with compositing enabled will honor it, some window managers won't.
            color: Qt.alpha(Theme.background, Theme.windowOpacity)

            // Fired after the OS has already destroyed this window.
            onClosed: {
                windowLoader.active = false;
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
}