import QtQuick
import QtQuick.Controls.Basic
import qs.modules

Popup {
    id: popup
    property string songId: ""
    width: 240
    height: Math.min(320, list.contentHeight + newRow.height + 24)
    modal: true
    focus: true
    padding: 8
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Theme.surface
        radius: Theme.cornerRadius * 0.6
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.08)
    }

    function openFor(id) {
        popup.songId = id
        popup.open()
    }

    Item {
        id: content
        anchors.fill: parent

        ListView {
            id: list
            width: parent.width
            height: parent.height - newRow.height - 8
            clip: true
            model: Backend.playlists
            delegate: Rectangle {
                width: list.width
                height: 34
                radius: 6
                color: rowHover.hovered ? Theme.surfaceAlt : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    elide: Text.ElideRight
                    width: parent.width - 16
                }
                HoverHandler { id: rowHover }
                TapHandler {
                    onTapped: {
                        Backend.addToPlaylist(modelData.name, popup.songId)
                        popup.close()
                    }
                }
            }
        }

        Row {
            id: newRow
            width: parent.width
            height: 34
            spacing: 6
            anchors.bottom: parent.bottom

            TextField {
                id: newName
                width: parent.width - 60
                placeholderText: "New playlist..."
                color: Theme.text
                font.family: Theme.fontFamily
                placeholderTextColor: Theme.textMuted
                background: Rectangle { color: Theme.surfaceAlt; radius: 6 }
                onAccepted: createBtn.doCreate()
            }
            Rectangle {
                id: createBtn
                width: 54; height: 30
                radius: 6
                color: Theme.accent
                function doCreate() {
                    if (newName.text.trim().length === 0) return
                    Backend.createPlaylist(newName.text.trim())
                    Backend.addToPlaylist(newName.text.trim(), popup.songId)
                    newName.text = ""
                    popup.close()
                }
                Text {
                    anchors.centerIn: parent
                    text: "Add"
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                TapHandler { onTapped: createBtn.doCreate() }
            }
        }
    }
}
