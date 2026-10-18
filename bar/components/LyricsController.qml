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
    property string phase: "get"
    property int attempts: 0

    function retryTransient() {
        if (phase === "get") { phase = "getLoose"; attempts = 0 }
        else if (attempts < 1) attempts++
        else if (phase === "getLoose") { phase = "search"; attempts = 0 }
        else { status = "error"; return }
        retryDelay.restart()
    }

    function cancel() {
        generation++
        timeout.stop()
        retryDelay.stop()
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
        phase = "get"
        attempts = 0
        sendRequest()
    }
    function sendRequest() {
        const token = generation, signature = key, currentPhase = phase
        const xhr = new XMLHttpRequest()
        request = xhr
        let url = (currentPhase !== "search" ? endpoint : endpoint.replace(/\/get$/, "/search")) +
            "?track_name=" + encodeURIComponent(title) + "&artist_name=" + encodeURIComponent(artist)
        if (currentPhase !== "search") {
            if (currentPhase === "get" && album.trim()) url += "&album_name=" + encodeURIComponent(album)
            if (isFinite(duration) && duration >= 1 && duration <= 3600) url += "&duration=" + Math.round(duration)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || token !== root.generation || signature !== root.key || !root.active) return
            timeout.stop(); root.request = null
            if (xhr.status === 404 && currentPhase !== "search") { root.phase = currentPhase === "get" ? "getLoose" : "search"; root.attempts = 0; root.sendRequest(); return }
            if (xhr.status === 429 || xhr.status >= 500 || xhr.status === 0) {
                root.retryTransient(); return
            }
            if (xhr.status === 404 && currentPhase === "search") { root.status = "empty"; return }
            if (xhr.status !== 200) { root.status = "error"; return }
            try {
                if (xhr.responseText.length > 250000) throw new Error("Response too large")
                const payload = JSON.parse(xhr.responseText)
                const record = LyricsData.bestMatch(currentPhase === "search" ? payload : [payload],
                    root.title, root.artist, root.album, root.duration)
                if (!record) {
                    if (currentPhase !== "search") { root.phase = currentPhase === "get" ? "getLoose" : "search"; root.attempts = 0; root.sendRequest(); return }
                    root.status = "empty"; return
                }
                const result = LyricsData.decode(record)
                if (result.status === "empty" && currentPhase !== "search") {
                    root.phase = currentPhase === "get" ? "getLoose" : "search"
                    root.attempts = 0; root.sendRequest(); return
                }
                root.lines = result.lines
                root.synced = result.synced
                root.status = result.status
                if (result.status === "ready" || result.status === "instrumental") root.loadedKey = signature
            } catch (error) { root.status = "error" }
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("Accept", "application/json")
        xhr.send()
        timeout.requestToken = token
        timeout.requestKey = signature
        timeout.restart()
    }
    onKeyChanged: invalidate()
    onActiveChanged: { if (active) debounce.restart(); else { debounce.stop(); cancel() } }
    Component.onDestruction: cancel()
    property Timer debounce: Timer { interval: 150; onTriggered: root.load() }
    property Timer timeout: Timer {
        interval: 8000
        property int requestToken: -1
        property string requestKey: ""
        onTriggered: {
            if (!root.active || root.status !== "loading" || requestToken !== root.generation || requestKey !== root.key || !root.request) return
            root.request.onreadystatechange = null
            root.request.abort()
            root.request = null
            root.retryTransient()
        }
    }
    property Timer retryDelay: Timer {
        interval: 1000
        onTriggered: root.sendRequest()
    }
}
