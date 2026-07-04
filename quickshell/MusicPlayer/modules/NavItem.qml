// NavItem.qml - a single row in the sidebar (All Songs / Favorites /
// each playlist). This file was referenced by Sidebar.qml but wasn't
// among the files you had, so it's a new addition needed to make the
// sidebar actually work.
import QtQuick
import QtQuick.Layouts
import qs.modules

Rectangle {
    id: item
    property string label: ""
    property string glyph: ""
    property bool active: false

    signal clicked()

    implicitWidth: 200
    implicitHeight: 34
    radius: Theme.controlRadius
    color: item.active ? Qt.alpha(Theme.accent, 0.18)
         : (hover.hovered ? Theme.surfaceAlt : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.anim(120) } }

    HoverHandler { id: hover }
    TapHandler { onTapped: item.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
            text: item.glyph
            color: item.active ? Theme.accent : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            Layout.preferredWidth: 16
        }
        Text {
            text: item.label
            color: item.active ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.bold: item.active
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
