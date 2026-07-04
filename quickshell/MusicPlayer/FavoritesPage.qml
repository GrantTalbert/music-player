import QtQuick
import qs.modules

SongList {
    title: "Favorites"
    emptyText: "No favorites yet - tap the heart on any song to add it here."
    songs: {
        const byId = {}
        for (const s of Backend.library) byId[s.id] = s
        return Backend.favoriteIds.map(id => byId[id]).filter(s => s !== undefined)
    }
    onPlayRequested: (index, shuffle) => {
        if (shuffle) {
            Backend.playFavorites(true)
        } else {
            Backend.playQueue(songs.map(s => s.id), index, false)
        }
    }
}
