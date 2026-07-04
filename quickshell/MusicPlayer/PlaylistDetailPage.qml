import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.modules

Item {
    id: root
    property string playlistName: ""
    signal deleted()

    readonly property var playlistData: {
        for (const p of Backend.playlists) if (p.name === root.playlistName) return p
        return null
    }

    readonly property var resolvedSongs: {
        if (!playlistData) return []
        const byId = {}
        for (const s of Backend.library) byId[s.id] = s
        return playlistData.songs
            .map(e => byId[e.id] || Object.assign({}, e, {_missing: true, duration: 0, art_url: ""}))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                glyph: "\u270E"
                size: 30
                onClicked: renamePopup.open()
            }
            IconButton {
                glyph: "\u2716"
                size: 30
                color: Theme.danger
                onClicked: deleteConfirmPopup.open()
            }
            Item { Layout.fillWidth: true }
        }

        SongList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: root.playlistName
            songs: root.resolvedSongs
            showRemove: true
            playlistNameForRemove: root.playlistName
            emptyText: "This playlist is empty. Use the + button on any song to add it here."
            onPlayRequested: (index, shuffle) => {
                if (shuffle) {
                    Backend.playPlaylist(root.playlistName, true, 0)
                } else {
                    Backend.playPlaylist(root.playlistName, false, index)
                }
            }
        }
    }

    Popup {
        id: renamePopup
        anchors.centerIn: parent
        width: 260
        modal: true
        focus: true
        background: Rectangle { color: Theme.surface; radius: Theme.cornerRadius * 0.6 }

        ColumnLayout {
            width: parent.width
            spacing: 8
            Text { text: "Rename playlist"; color: Theme.text; font.bold: true }
            TextField {
                id: renameField
                Layout.fillWidth: true
                text: root.playlistName
                color: Theme.text
                background: Rectangle { color: Theme.surfaceAlt; radius: 6 }
                onAccepted: {
                    Backend.renamePlaylist(root.playlistName, renameField.text.trim())
                    root.playlistName = renameField.text.trim()
                    renamePopup.close()
                }
            }
        }
    }

    Popup {
        id: deleteConfirmPopup
        anchors.centerIn: parent
        width: 300
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.surface
            radius: Theme.cornerRadius * 0.6
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)
        }

        ColumnLayout {
            width: parent.width
            spacing: 14

            Text {
                text: "Delete \u201C" + root.playlistName + "\u201D?"
                color: Theme.text
                font.bold: true
                font.pixelSize: Theme.fontSizeNormal
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                text: "Are you sure you want to delete this playlist? This can't be undone."
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 84; height: 32
                    radius: Theme.controlRadius
                    color: Theme.surfaceAlt
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.pixelSize: Theme.fontSizeSmall }
                    TapHandler { onTapped: deleteConfirmPopup.close() }
                }
                Rectangle {
                    width: 84; height: 32
                    radius: Theme.controlRadius
                    color: Theme.danger
                    Text { anchors.centerIn: parent; text: "Delete"; color: Theme.background; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                    TapHandler {
                        onTapped: {
                            deleteConfirmPopup.close()
                            Backend.deletePlaylist(root.playlistName)
                            root.deleted()
                        }
                    }
                }
            }
        }
    }
}
