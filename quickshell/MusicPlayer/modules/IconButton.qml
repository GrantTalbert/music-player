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
        // NOTE: previously this animated to/from the literal string
        // "transparent" (== black at alpha 0). Animating a color's RGB
        // channels from black towards Theme.surfaceAlt while alpha
        // ramps up produces a visible dark/hue "flash" partway through
        // the transition. Using the same RGB with alpha 0 as the rest
        // state makes it a pure alpha fade instead.
        color: btn.active ? Qt.alpha(Theme.accent, 0.25)
             : (hover.hovered ? Theme.surfaceAlt : Qt.alpha(Theme.surfaceAlt, 0))
        Behavior on color { ColorAnimation { duration: Theme.anim(120); easing.type: Theme.easingType() } }
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
