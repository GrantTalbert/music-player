// Keybinds.qml - loads ~/.config/quickshell-musicplayer/keybinds.json
// and maps key names (strings) to player actions. Only active while
// the player window has keyboard focus (wired up from the focus scope
// in shell.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell-musicplayer/keybinds.json"

    // action -> key name string, e.g. {"play_pause": "P"}. Defaults
    // below are used for any action missing from the user's file.
    property var bindings: ({
        "play_pause": "Space",
        "next": "Right",
        "previous": "Left",
        "seek_forward": "L",
        "seek_backward": "H",
        "volume_up": "Up",
        "volume_down": "Down",
        "toggle_shuffle": "S",
        "cycle_repeat": "R",
        "toggle_favorite": "F",
        "focus_search": "Slash",
    })

    FileView {
        id: file
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.bindings = Object.assign({}, root.bindings, parsed)
            } catch (e) {
                console.warn("Keybinds.qml: failed to parse", root.configPath, e)
            }
        }
        onLoadFailed: (error) => {
            console.warn("Keybinds.qml: could not load", root.configPath,
                         "- using built-in defaults. Run install.sh to create it.")
        }
    }

    // reverse lookup built once bindings change: keyName -> action
    property var _byKey: ({})
    
    function _rebuildByKey() {
        let map = {}
        for (const action in bindings) {
            map[String(bindings[action]).toLowerCase()] = action
        }
        root._byKey = map
    }

    onBindingsChanged: root._rebuildByKey()
    Component.onCompleted: root._rebuildByKey()

    function _keyName(event) {
        // Prefer the literal typed character for letter/digit keys so
        // this works regardless of keyboard layout quirks; fall back
        // to Qt's named keys for everything else.
        if (event.text && event.text.length === 1 && /[a-zA-Z0-9]/.test(event.text)) {
            return event.text.toLowerCase()
        }
        switch (event.key) {
            case Qt.Key_Space: return "space"
            case Qt.Key_Left: return "left"
            case Qt.Key_Right: return "right"
            case Qt.Key_Up: return "up"
            case Qt.Key_Down: return "down"
            case Qt.Key_Return:
            case Qt.Key_Enter: return "return"
            case Qt.Key_Escape: return "escape"
            case Qt.Key_Tab: return "tab"
            case Qt.Key_Slash: return "slash"
            case Qt.Key_Comma: return "comma"
            case Qt.Key_Period: return "period"
            default: return ""
        }
    }

    // returns the action name for a key event, or "" if unbound
    function actionFor(event) {
        const name = _keyName(event)
        if (!name) return ""
        return root._byKey[name] || ""
    }
}
