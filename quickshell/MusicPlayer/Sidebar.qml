import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.modules

Rectangle {
    id: sidebar
    color: Qt.alpha(Theme.surface, Theme.surfaceOpacity)
    radius: Theme.cornerRadius

    property string selected: "library"     // "library" | "favorites" | "playlist:<name>"
    signal selectedChanged2(string value)

    function select(v) {
        sidebar.selected = v
        sidebar.selectedChanged2(v)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding
        spacing: 4

        Text {
            text: Theme.appName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            Layout.bottomMargin: 12
        }

        NavItem {
            // NOTE: NavItem has a hardcoded implicitWidth of 200, which
            // is *wider* than the sidebar's actual content width once
            // Theme.padding margins are subtracted. Without
            // Layout.fillWidth it overflowed past the right edge,
            // making the left padding look bigger than the right.
            Layout.fillWidth: true
            label: "All Songs"
            glyph: "\u266A"
            active: sidebar.selected === "library"
            onClicked: sidebar.select("library")
        }
        NavItem {
            Layout.fillWidth: true
            label: "Favorites"
            glyph: "\u2665"
            active: sidebar.selected === "favorites"
            onClicked: sidebar.select("favorites")
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Theme.text, 0.08); Layout.topMargin: 10; Layout.bottomMargin: 6 }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "PLAYLISTS"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                Layout.fillWidth: true
            }
            IconButton {
                glyph: "+"
                size: 24
                onClicked: newPlaylistPopup.open()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Backend.playlists
            delegate: NavItem {
                width: ListView.view.width
                label: modelData.name
                glyph: "\u266B"
                active: sidebar.selected === ("playlist:" + modelData.name)
                onClicked: sidebar.select("playlist:" + modelData.name)
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Theme.text, 0.08) }

        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                width: 8; height: 8; radius: 4
                color: Backend.daemonConnected ? "#9ece6a" : Theme.danger
            }
            Text {
                text: Backend.daemonConnected ? "Connected" : "Reconnecting..."
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true
            }
            IconButton {
                glyph: "\u21BB"
                size: 24
                onClicked: Backend.rescanLibrary()
            }
        }
    }

    Popup {
        id: newPlaylistPopup
        anchors.centerIn: parent
        width: 260
        modal: true
        focus: true
        background: Rectangle { color: Theme.surface; radius: Theme.cornerRadius * 0.6 }

        ColumnLayout {
            width: parent.width
            spacing: 8
            Text { text: "New playlist"; color: Theme.text; font.family: Theme.fontFamily; font.bold: true }
            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "Playlist name"
                color: Theme.text
                font.family: Theme.fontFamily
                placeholderTextColor: Theme.textMuted
                background: Rectangle { color: Theme.surfaceAlt; radius: 6 }
                onAccepted: {
                    if (text.trim().length > 0) {
                        Backend.createPlaylist(text.trim())
                        sidebar.select("playlist:" + text.trim())
                    }
                    text = ""
                    newPlaylistPopup.close()
                }
            }
        }
    }
}
