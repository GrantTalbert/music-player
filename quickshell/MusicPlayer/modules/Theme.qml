// Theme.qml - loads every visual/rice-able knob from a JSON file on
// disk so the player can be themed without touching QML. Edit
// ~/.config/quickshell-musicplayer/theme.json (created on first run
// from config/theme.json) and the UI updates live (watchChanges: true).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell-musicplayer/theme.json"

    // ---- sensible fallbacks, used until the file loads (or if a key
    // is missing from the user's theme.json) ----
    property color background: "#1a1b26"
    property color surface: "#20222f"
    property color surfaceAlt: "#282a3a"
    property color accent: "#7aa2f7"
    property color accentAlt: "#bb9af7"
    property color text: "#c0caf5"
    property color textMuted: "#565f89"
    property color danger: "#f7768e"
    property color favoriteColor: "#f7768e"

    property real cornerRadius: 14
    property real controlRadius: 999
    property real windowOpacity: 0.96
    property real surfaceOpacity: 0.85
    property real blurRadius: 24

    property bool animationsEnabled: true
    property int animationDuration: 180
    property string animationEasing: "OutCubic"

    property string backgroundImage: ""      // absolute path or "" for none
    property real backgroundImageOpacity: 0.35
    property bool backgroundImageBlur: true

    property string fontFamily: "sans-serif"
    property int fontSizeSmall: 11
    property int fontSizeNormal: 13
    property int fontSizeLarge: 16
    property int fontSizeHuge: 22

    property real spacing: 10
    property real padding: 16

    // ---- structural knobs, not just colors/sizes ----
    // Whether song rows / the now-playing bar show album art thumbnails
    // at all (rather than just recoloring the placeholder). Turning
    // this off removes the art slot from the layout entirely.
    property bool showArtwork: true
    // Shrinks each song row and drops the artist line, for a denser
    // list. This is a real layout change, not a palette swap.
    property bool compactRows: false

    // Text shown top-left in the sidebar. Configurable so you don't
    // have to fork the QML just to rename the app.
    property string appName: "Quickshell Music"

    // ---- loading ----
    FileView {
        id: file
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._apply(JSON.parse(text()))
        onLoadFailed: (error) => {
            console.warn("Theme.qml: could not load", root.configPath, "-", error,
                         "- falling back to built-in defaults. Run install.sh to create it.")
        }
    }

    function _apply(t) {
        if (!t) return
        if (t.background !== undefined) root.background = t.background
        if (t.surface !== undefined) root.surface = t.surface
        if (t.surfaceAlt !== undefined) root.surfaceAlt = t.surfaceAlt
        if (t.accent !== undefined) root.accent = t.accent
        if (t.accentAlt !== undefined) root.accentAlt = t.accentAlt
        if (t.text !== undefined) root.text = t.text
        if (t.textMuted !== undefined) root.textMuted = t.textMuted
        if (t.danger !== undefined) root.danger = t.danger
        if (t.favoriteColor !== undefined) root.favoriteColor = t.favoriteColor

        if (t.cornerRadius !== undefined) root.cornerRadius = t.cornerRadius
        if (t.controlRadius !== undefined) root.controlRadius = t.controlRadius
        if (t.windowOpacity !== undefined) root.windowOpacity = t.windowOpacity
        if (t.surfaceOpacity !== undefined) root.surfaceOpacity = t.surfaceOpacity
        if (t.blurRadius !== undefined) root.blurRadius = t.blurRadius

        if (t.animationsEnabled !== undefined) root.animationsEnabled = t.animationsEnabled
        if (t.animationDuration !== undefined) root.animationDuration = t.animationDuration
        if (t.animationEasing !== undefined) root.animationEasing = t.animationEasing

        if (t.backgroundImage !== undefined) root.backgroundImage = t.backgroundImage
        if (t.backgroundImageOpacity !== undefined) root.backgroundImageOpacity = t.backgroundImageOpacity
        if (t.backgroundImageBlur !== undefined) root.backgroundImageBlur = t.backgroundImageBlur

        if (t.fontFamily !== undefined) root.fontFamily = t.fontFamily
        if (t.fontSizeSmall !== undefined) root.fontSizeSmall = t.fontSizeSmall
        if (t.fontSizeNormal !== undefined) root.fontSizeNormal = t.fontSizeNormal
        if (t.fontSizeLarge !== undefined) root.fontSizeLarge = t.fontSizeLarge
        if (t.fontSizeHuge !== undefined) root.fontSizeHuge = t.fontSizeHuge

        if (t.spacing !== undefined) root.spacing = t.spacing
        if (t.padding !== undefined) root.padding = t.padding

        if (t.showArtwork !== undefined) root.showArtwork = t.showArtwork
        if (t.compactRows !== undefined) root.compactRows = t.compactRows

        if (t.appName !== undefined) root.appName = t.appName
    }

    // Helper for QML animations that respect the animationsEnabled toggle.
    function anim(duration) {
        return root.animationsEnabled ? duration : 0
    }

    // Maps the human-readable `animationEasing` string from theme.json
    // to an actual Easing.Type curve. Previously this property was
    // loaded from JSON but never plugged into any Behavior/Animation,
    // so changing it in theme.json silently did nothing - every
    // Behavior now calls this instead of hardcoding a curve.
    function easingType() {
        const map = {
            "Linear": Easing.Linear,
            "InQuad": Easing.InQuad, "OutQuad": Easing.OutQuad, "InOutQuad": Easing.InOutQuad,
            "InCubic": Easing.InCubic, "OutCubic": Easing.OutCubic, "InOutCubic": Easing.InOutCubic,
            "InQuart": Easing.InQuart, "OutQuart": Easing.OutQuart, "InOutQuart": Easing.InOutQuart,
            "InBack": Easing.InBack, "OutBack": Easing.OutBack, "InOutBack": Easing.InOutBack,
            "InBounce": Easing.InBounce, "OutBounce": Easing.OutBounce, "InOutBounce": Easing.InOutBounce,
            "InElastic": Easing.InElastic, "OutElastic": Easing.OutElastic, "InOutElastic": Easing.InOutElastic,
        }
        return map[root.animationEasing] !== undefined ? map[root.animationEasing] : Easing.OutCubic
    }

    // mm:ss (or h:mm:ss for long files) formatter shared by every view.
    function formatTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds)) return "0:00"
        const total = Math.floor(seconds)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        const mm = h > 0 ? String(m).padStart(2, "0") : String(m)
        const ss = String(s).padStart(2, "0")
        return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
    }
}
