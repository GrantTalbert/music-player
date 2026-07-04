import QtQuick
import qs.modules

Item {
    id: btn
    property string glyph: "?"
    property color color: Theme.text
    property real size: 36
    property real fontSize: size * 0.5
    property bool flat: true
    property bool active: false

    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: btn.active ? Qt.alpha(Theme.accent, 0.25)
             : (hover.hovered ? Theme.surfaceAlt : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.anim(120) } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.active ? Theme.accent : btn.color
        font.pixelSize: btn.fontSize
    }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: btn.clicked()
    }
}
