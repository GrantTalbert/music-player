// Backend.qml - talks to musicplayerd over its unix socket JSON
// protocol (see daemon/ipc_server.py for the wire format) and exposes
// everything as plain reactive QML properties + functions for the UI.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- connection state ----
    property bool daemonConnected: false
    property string statusMessage: "Connecting to musicplayerd..."

    // ---- player state (mirrors daemon "state" events) ----
    property bool playing: false
    property bool stopped: true
    property var currentTrack: null   // {id,title,artist,album,art_url,duration,track_no,path}
    property real position: 0
    property real duration: 0
    property real volume: 1.0
    property bool shuffle: false
    property string repeat: "off"     // off | one | all
    property bool favorite: false
    property int queueIndex: -1
    property int queueLength: 0
    property var source: ({type: "none", name: null})

    // ---- library / playlists / favorites ----
    property var library: []          // array of song objects
    property var playlists: []        // array of {name, created, songs:[...]}
    property var favoriteIds: []      // array of song ids, in favorited order

    signal errorReceived(string message)

    // ------------------------------------------------------------------
    // resolve $HOME once, then figure out the socket path exactly the
    // way util.py does (XDG_RUNTIME_DIR preferred, ~/.cache fallback)
    // ------------------------------------------------------------------
    property string socketPath: ""

    Process {
        id: resolvePath
        command: ["sh", "-c",
            "if [ -n \"$XDG_RUNTIME_DIR\" ]; then base=\"$XDG_RUNTIME_DIR/quickshell-musicplayer\"; " +
            "else base=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-musicplayer/run\"; fi; " +
            "printf '%s/ipc.sock' \"$base\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.socketPath = this.text
                sock.path = this.text
                sock.connected = true
            }
        }
    }

    Component.onCompleted: resolvePath.running = true

    // ------------------------------------------------------------------
    // socket connection + retry
    // ------------------------------------------------------------------
    Socket {
        id: sock
        connected: false

        parser: SplitParser {
            onRead: data => root._handleLine(data)
        }

        onConnectedChanged: {
            root.daemonConnected = sock.connected
            root.statusMessage = sock.connected ? "" : "Disconnected from musicplayerd - retrying..."
        }
    }

    Timer {
        // keeps retrying the connection; harmless no-op once connected
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (root.socketPath.length > 0 && !sock.connected) {
                sock.path = root.socketPath
                sock.connected = true
            }
        }
    }

    // ------------------------------------------------------------------
    // incoming message handling
    // ------------------------------------------------------------------
    function _handleLine(line) {
        let msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            console.warn("Backend: bad JSON from daemon:", line)
            return
        }

        if (msg.event !== undefined) {
            _handleEvent(msg.event, msg.data)
            return
        }
        if (msg.ok === false) {
            console.warn("Backend: command failed:", msg.error)
            root.errorReceived(msg.error || "unknown error")
        }
        // successful command responses mostly just duplicate state,
        // which will also arrive via the "state" broadcast event, so
        // we don't need to do anything else with them here.
    }

    function _handleEvent(event, data) {
        if (event === "snapshot") {
            _applyState(data.state)
            root.library = data.library || []
            root.playlists = data.playlists || []
            root.favoriteIds = data.favorites || []
        } else if (event === "state") {
            _applyState(data)
        } else if (event === "position") {
            root.position = data.position
            root.duration = data.duration
        } else if (event === "library") {
            root.library = data
        } else if (event === "playlists") {
            root.playlists = data
        } else if (event === "favorites") {
            root.favoriteIds = data
        }
    }

    function _applyState(s) {
        if (!s) return
        root.playing = !!s.playing
        root.stopped = !!s.stopped
        root.currentTrack = s.current || null
        root.position = s.position || 0
        root.duration = s.duration || 0
        root.volume = s.volume !== undefined ? s.volume : root.volume
        root.shuffle = !!s.shuffle
        root.repeat = s.repeat || "off"
        root.favorite = !!s.favorite
        root.queueIndex = s.queue_index !== undefined ? s.queue_index : -1
        root.queueLength = s.queue_length || 0
        root.source = s.source || {type: "none", name: null}
    }

    // ------------------------------------------------------------------
    // outgoing commands
    // ------------------------------------------------------------------
    property int _nextId: 1

    function _send(cmd, extra) {
        if (!sock.connected) {
            console.warn("Backend: cannot send '" + cmd + "', not connected")
            return
        }
        let obj = extra ? Object.assign({}, extra) : {}
        // NOTE: this used to be `obj.id = root._nextId++`, which
        // clobbered any "id" field already present in `extra`.
        // toggleFavorite, addToPlaylist, and removeFromPlaylist all
        // pass a *song* id as `{id: ...}` -- so the song id was getting
        // silently overwritten with this request counter before the
        // message ever left the client, and the daemon (which also
        // used "id" for request/response correlation) had no way to
        // tell the difference. That's why favoriting looked like it
        // did nothing, and why adding to a playlist failed with
        // "unknown song id". The correlation id now lives under its
        // own key, "req_id" (matching the renamed field in
        // daemon/ipc_server.py), so it can never collide with a
        // command's own payload fields again.
        obj.req_id = root._nextId++
        obj.cmd = cmd
        sock.write(JSON.stringify(obj) + "\n")
    }

    function playPause() { _send("play_pause") }
    function play() { _send("play") }
    function pause() { _send("pause") }
    function stop() { _send("stop") }
    function next() { _send("next") }
    function previous() { _send("previous") }
    function seek(positionSeconds) { _send("seek", {position: positionSeconds}) }
    function seekRelative(deltaSeconds) { _send("seek_relative", {delta: deltaSeconds}) }
    function setVolume(v) { _send("set_volume", {volume: v}) }
    function setShuffle(enabled) { _send("set_shuffle", {enabled: enabled}) }
    function cycleRepeat() {
        const order = ["off", "one", "all"]
        const next = order[(order.indexOf(root.repeat) + 1) % order.length]
        _send("set_repeat", {mode: next})
    }

    function playSong(id) { _send("play_song", {id: id}) }
    function playQueue(ids, index, shuffle) { _send("play_queue", {ids: ids, index: index || 0, shuffle: !!shuffle}) }
    function playAll(shuffle) { _send("play_all", {shuffle: !!shuffle}) }
    function playPlaylist(name, shuffle, index) { _send("play_playlist", {name: name, shuffle: !!shuffle, index: index || 0}) }
    function playFavorites(shuffle) { _send("play_favorites", {shuffle: !!shuffle}) }

    function toggleFavorite(id) { _send("toggle_favorite", {id: id}) }
    function isFavorite(id) { return root.favoriteIds.indexOf(id) !== -1 }

    function createPlaylist(name) { _send("create_playlist", {name: name}) }
    function deletePlaylist(name) { _send("delete_playlist", {name: name}) }
    function renamePlaylist(oldName, newName) { _send("rename_playlist", {old: oldName, new: newName}) }
    function addToPlaylist(name, id) { _send("add_to_playlist", {name: name, id: id}) }
    function removeFromPlaylist(name, id) { _send("remove_from_playlist", {name: name, id: id}) }
    function reorderPlaylist(name, ids) { _send("reorder_playlist", {name: name, ids: ids}) }

    function rescanLibrary() { _send("rescan_library") }
}
