import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.modules

Item {
    id: root
    property string title: ""
    property var songs: []                 // full array of song objects, already ordered
    property bool showRemove: false
    property string playlistNameForRemove: ""
    property string emptyText: "No songs here yet."
    property bool showSearch: true

    signal playRequested(int index, bool shuffle)  // play `songs` starting at index

    property string _filter: ""
    readonly property var _filtered: {
        if (_filter.trim().length === 0) return root.songs
        const f = _filter.toLowerCase()
        return root.songs.filter(s =>
            (s.title || "").toLowerCase().includes(f) ||
            (s.artist || "").toLowerCase().includes(f) ||
            (s.album || "").toLowerCase().includes(f))
    }

    AddToPlaylistPopup { id: addPopup }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing

            Text {
                text: root.title
                color: Theme.text
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: root.songs.length + (root.songs.length === 1 ? " song" : " songs")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
            }

            IconButton { glyph: "\u25B6"; size: 34; onClicked: root.playRequested(0, false) }
            IconButton { glyph: "\u21C0"; size: 34; onClicked: root.playRequested(0, true) }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.showSearch
            height: 34
            radius: Theme.controlRadius
            color: Theme.surfaceAlt

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.pixelSize: Theme.fontSizeNormal
                clip: true
                onTextChanged: root._filter = text

                Text {
                    visible: searchInput.text.length === 0
                    text: "Search this list..."
                    color: Theme.textMuted
                    font: searchInput.font
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            visible: root._filtered.length === 0
            text: root.emptyText
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeNormal
            Layout.topMargin: 24
            Layout.alignment: Qt.AlignHCenter
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root._filtered
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: SongRow {
                width: ListView.view.width
                song: modelData
                isCurrent: Backend.currentTrack && Backend.currentTrack.id === modelData.id
                showRemove: root.showRemove
                onClicked: {
                    // find this song's index within the *unfiltered* list so
                    // Next/Previous still walks the full, expected order
                    const idx = root.songs.findIndex(s => s.id === modelData.id)
                    root.playRequested(idx >= 0 ? idx : 0, false)
                }
                onFavoriteClicked: Backend.toggleFavorite(modelData.id)
                onAddToPlaylistClicked: addPopup.openFor(modelData.id)
                onRemoveClicked: Backend.removeFromPlaylist(root.playlistNameForRemove, modelData.id)
            }
        }
    }
}
