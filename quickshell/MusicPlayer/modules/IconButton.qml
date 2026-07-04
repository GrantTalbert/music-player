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
        // Previously the hover fill was Theme.surfaceAlt, the same
        // opaque color SongRow uses for its own hover background. That
        // meant hovering the heart/+ buttons *inside* a SongRow (which
        // is necessarily also being hovered, since your cursor has to
        // be over the row to reach the button) painted the exact same
        // color the row itself had already painted underneath it - so
        // the "highlight" was invisible, not actually absent. Using a
        // low-alpha overlay of Theme.text instead is visible against
        // any background (row hovered or not, current-track tint or
        // not) since it's a translucent tint rather than a same-color
        // opaque fill.
        //
        // Both states share the same base color (Theme.text) so the
        // Behavior below only animates alpha, not hue - see the note
        // on this same pattern elsewhere (SongRow, NavItem): animating
        // between two different RGB colors while alpha ramps produces
        // a visible color "flash" partway through.
        color: btn.active ? Qt.alpha(Theme.accent, 0.25)
             : (hover.hovered ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0))
        Behavior on color { ColorAnimation { duration: Theme.anim(120); easing.type: Theme.easingType() } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.active ? Theme.accent : btn.color
        font.family: Theme.fontFamily
        font.pixelSize: btn.fontSize
    }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: btn.clicked()
    }
}
