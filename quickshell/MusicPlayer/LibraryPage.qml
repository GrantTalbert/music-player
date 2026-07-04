import QtQuick
import qs.modules

SongList {
    title: "All Songs"
    songs: Backend.library
    emptyText: "No music found. Check that ~/Music has some audio files, then hit rescan."
    onPlayRequested: (index, shuffle) => {
        const ids = songs.map(s => s.id)
        Backend.playQueue(ids, index, shuffle)
    }
}
