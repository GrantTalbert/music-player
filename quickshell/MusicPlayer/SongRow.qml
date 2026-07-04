import QtQuick
import QtQuick.Layouts
import qs.modules

Rectangle {
    id: row
    required property var song            // {id,title,artist,album,duration,art_url,track_no}
    property bool isCurrent: false
    property bool showRemove: false
    property bool showAddToPlaylist: true

    signal clicked()
    signal favoriteClicked()
    signal removeClicked()
    signal addToPlaylistClicked()

    height: 56
    radius: Theme.cornerRadius * 0.5
    color: hover.hovered ? Theme.surfaceAlt : (isCurrent ? Qt.alpha(Theme.accent, 0.12) : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.anim(120) } }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: row.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: Theme.spacing

        // art thumbnail
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 8
            color: Theme.surfaceAlt
            Image {
                anchors.fill: parent
                source: row.song.art_url || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: row.song.art_url && row.song.art_url.length > 0
            }
            Text {
                anchors.centerIn: parent
                visible: !row.song.art_url || row.song.art_url.length === 0
                text: "\u266B"
                color: Theme.textMuted
                font.pixelSize: 16
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Text {
                width: parent.width
                text: row.song.title || ""
                color: row.isCurrent ? Theme.accent : Theme.text
                font.pixelSize: Theme.fontSizeNormal
                font.bold: row.isCurrent
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: row.song.artist || ""
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Text {
            text: Theme.formatTime(row.song.duration || 0)
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
        }

        IconButton {
            glyph: Backend.isFavorite(row.song.id) ? "\u2665" : "\u2661"
            color: Backend.isFavorite(row.song.id) ? Theme.favoriteColor : Theme.textMuted
            size: 30
            onClicked: row.favoriteClicked()
        }

        IconButton {
            visible: row.showAddToPlaylist
            glyph: "+"
            size: 30
            onClicked: row.addToPlaylistClicked()
        }

        IconButton {
            visible: row.showRemove
            glyph: "\u2715"
            color: Theme.danger
            size: 30
            onClicked: row.removeClicked()
        }
    }
}
