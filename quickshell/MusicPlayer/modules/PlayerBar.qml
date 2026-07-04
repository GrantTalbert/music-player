// PlayerBar.qml - the persistent "now playing" bar: art, title, artist,
// transport controls (prev/play-pause/next), shuffle/repeat toggles,
// favorite toggle, and a seek bar. None of the files you had actually
// implemented this, so it's a new addition, built to match the visual
// style of the rest of the app (IconButton, Theme, etc).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.modules

Rectangle {
    id: bar
    implicitHeight: 88
    radius: Theme.cornerRadius
    color: Qt.alpha(Theme.surface, Theme.surfaceOpacity)

    readonly property var track: Backend.currentTrack

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: Theme.spacing

        // ---- art + title/artist ----
        Rectangle {
            visible: Theme.showArtwork
            Layout.preferredWidth: Theme.showArtwork ? 56 : 0
            Layout.preferredHeight: 56
            radius: 10
            color: Theme.surfaceAlt
            Image {
                anchors.fill: parent
                source: (bar.track && bar.track.art_url) ? bar.track.art_url : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: bar.track && bar.track.art_url && bar.track.art_url.length > 0
            }
            Text {
                anchors.centerIn: parent
                visible: !bar.track || !bar.track.art_url || bar.track.art_url.length === 0
                text: "\u266B"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }
        }

        Column {
            Layout.preferredWidth: 190
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                width: parent.width
                text: bar.track ? (bar.track.title || "") : "Nothing playing"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: bar.track ? (bar.track.artist || "") : ""
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        IconButton {
            glyph: Backend.favorite ? "\u2665" : "\u2661"
            color: Backend.favorite ? Theme.favoriteColor : Theme.textMuted
            size: 28
            onClicked: if (bar.track) Backend.toggleFavorite(bar.track.id)
        }

        // ---- transport controls + seek bar ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                IconButton {
                    glyph: "\u21C4"
                    size: 28
                    active: Backend.shuffle
                    onClicked: Backend.setShuffle(!Backend.shuffle)
                }
                IconButton {
                    glyph: "\u23EE"
                    size: 32
                    onClicked: Backend.previous()
                }
                IconButton {
                    glyph: Backend.playing ? "\u23F8" : "\u25B6"
                    size: 40
                    onClicked: Backend.playPause()
                }
                IconButton {
                    glyph: "\u23ED"
                    size: 32
                    onClicked: Backend.next()
                }
                IconButton {
                    glyph: Backend.repeat === "one" ? "1" : "\u21BB"
                    size: 28
                    active: Backend.repeat !== "off"
                    onClicked: Backend.cycleRepeat()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Theme.formatTime(Backend.position)
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }

                Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(Backend.duration, 0.001)
                    value: pressed ? value : Backend.position
                    onMoved: Backend.seek(value)

                    background: Rectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: seekSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Theme.surfaceAlt
                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }
                    handle: Rectangle {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.accent
                    }
                }

                Text {
                    text: Theme.formatTime(Backend.duration)
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.preferredWidth: 40
                }
            }
        }

        // ---- volume ----
        RowLayout {
            Layout.preferredWidth: 120
            spacing: 6
            Text {
                text: "\u{1F50A}"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
            Slider {
                id: volSlider
                Layout.fillWidth: true
                from: 0
                to: 1.5
                value: pressed ? value : Backend.volume
                onMoved: Backend.setVolume(value)

                background: Rectangle {
                    x: volSlider.leftPadding
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    width: volSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Theme.surfaceAlt
                    Rectangle {
                        width: volSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Theme.accentAlt
                    }
                }
                handle: Rectangle {
                    x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.accentAlt
                }
            }
        }
    }
}
