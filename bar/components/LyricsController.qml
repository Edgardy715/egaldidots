import QtQuick
import "LyricsData.js" as LyricsData

QtObject {
    id: root
    property bool active: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property real duration: 0
    property string endpoint: "https://lrclib.net/api/get"
    readonly property string key: JSON.stringify([title, artist, album, Math.round(duration)])
    property string loadedKey: ""
    property string status: "idle"
    property bool synced: false
    property var lines: []
    property var request: null
    property int generation: 0

    function cancel() {
        generation++
        timeout.stop()
        if (request) { request.onreadystatechange = null; request.abort(); request = null }
        if (status === "loading") status = "idle"
    }
    function invalidate() {
        cancel()
        loadedKey = ""
        lines = []
        synced = false
        status = "idle"
        if (active) debounce.restart()
    }
    function retry() { loadedKey = ""; if (active) load() }
    function load() {
        if (!active || loadedKey === key) return
        cancel()
        lines = []; synced = false
        if (!title.trim() || !artist.trim()) { status = "metadata"; return }
        status = "loading"
        const token = generation
        const signature = key
        const xhr = new XMLHttpRequest()
        request = xhr
        let url = endpoint + "?track_name=" + encodeURIComponent(title) + "&artist_name=" + encodeURIComponent(artist)
        if (album.trim()) url += "&album_name=" + encodeURIComponent(album)
        if (isFinite(duration) && duration >= 1 && duration <= 3600) url += "&duration=" + Math.round(duration)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || token !== root.generation || signature !== root.key || !root.active) return
            timeout.stop(); root.request = null
            if (xhr.status === 404) { root.status = "empty"; root.loadedKey = signature; return }
            if (xhr.status !== 200) { root.status = "error"; return }
            try {
                if (xhr.responseText.length > 250000) throw new Error("Response too large")
                const result = LyricsData.decode(JSON.parse(xhr.responseText))
                root.lines = result.lines
                root.synced = result.synced
                root.status = result.status
                root.loadedKey = signature
            } catch (error) { root.status = "error" }
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("Accept", "application/json")
        xhr.send()
        timeout.restart()
    }
    onKeyChanged: invalidate()
    onActiveChanged: { if (active) debounce.restart(); else { debounce.stop(); cancel() } }
    Component.onDestruction: cancel()
    property Timer debounce: Timer { interval: 150; onTriggered: root.load() }
    property Timer timeout: Timer {
        interval: 12000
        onTriggered: { root.cancel(); root.status = "error" }
    }
}
