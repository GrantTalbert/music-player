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

    // Playlist entries whose file has since been moved/renamed/deleted
    // come through as {..., _missing: true} (see PlaylistDetailPage's
    // resolvedSongs). There's no real library entry behind these, so
    // favoriting/adding-to-playlist them can only ever fail with
    // "unknown song id" - we just disable those actions instead.
    readonly property bool isMissing: !!(row.song && row.song._missing)

    // Guard used to stop a tap on the heart/+/x icons from *also*
    // being interpreted as a tap on the row itself. QtQuick's
    // TapHandler doesn't automatically stop a tap from propagating to
    // an ancestor's TapHandler the way an old-style MouseArea would,
    // so without this, clicking any icon button also fired row.clicked()
    // underneath it (which restarted playback). Each icon button sets
    // this flag first; because child items receive pointer events
    // before their ancestors, it's reliably set before the row's own
    // TapHandler evaluates.
    property bool suppressClick: false

    height: 56
    radius: Theme.cornerRadius * 0.5
    // Same transparent-animation artifact as IconButton/NavItem - see
    // notes there. Fixed the same way here.
    color: hover.hovered ? Theme.surfaceAlt
         : (isCurrent ? Qt.alpha(Theme.accent, 0.12) : Qt.alpha(Theme.surfaceAlt, 0))

    Behavior on color { ColorAnimation { duration: Theme.anim(120); easing.type: Theme.easingType() } }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: {
            if (row.suppressClick) {
                row.suppressClick = false
                return
            }
            if (!row.isMissing) row.clicked()
        }
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
            opacity: row.isMissing ? 0.4 : 1
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
                text: (row.song.title || "") + (row.isMissing ? "  \u00B7 missing" : "")
                color: row.isMissing ? Theme.textMuted : (row.isCurrent ? Theme.accent : Theme.text)
                font.pixelSize: Theme.fontSizeNormal
                font.bold: row.isCurrent && !row.isMissing
                font.italic: row.isMissing
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
            enabled: !row.isMissing
            opacity: row.isMissing ? 0.35 : 1
            onClicked: {
                row.suppressClick = true
                row.favoriteClicked()
            }
        }

        IconButton {
            visible: row.showAddToPlaylist
            glyph: "+"
            size: 30
            enabled: !row.isMissing
            opacity: row.isMissing ? 0.35 : 1
            onClicked: {
                row.suppressClick = true
                row.addToPlaylistClicked()
            }
        }

        IconButton {
            visible: row.showRemove
            glyph: "\u2715"
            color: Theme.danger
            size: 30
            onClicked: {
                row.suppressClick = true
                row.removeClicked()
            }
        }
    }
}
