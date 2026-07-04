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
                onClicked: {
                    Backend.deletePlaylist(root.playlistName)
                    root.deleted()
                }
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
}
