pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "MediaSource.js" as MediaSource

/** Adaptador Mpris: filtra playerctld y reproductores detenidos, prioriza la reproducción y mantiene el player activo al cambiar metadata.
 * Basado en Ricelin Players.qml.
 */
Singleton {
    id: root

    function isProxy(p) {
        return (p && p.dbusName ? p.dbusName : "").toLowerCase().indexOf("playerctld") >= 0
    }

    readonly property var list: {
        void Mpris.players.values
        var all = Mpris.players.values
        var out = []
        for (var i = 0; i < all.length; i++)
            if (all[i] && !isProxy(all[i])
                    && all[i].playbackState !== MprisPlaybackState.Stopped) out.push(all[i])
        return out
    }

    /** player fijado manualmente (por el switcher ‹› del MediaSurface), o null.
     *  Si está set y aún vive en `list` → tiene prioridad; si se fue, auto-cae. */
    property var manual: null
    property var recent: null

    readonly property var active: {
        var l = root.list
        if (root.manual && l.indexOf(root.manual) >= 0) return root.manual
        for (var i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i]
        if (root.recent && l.indexOf(root.recent) >= 0) return root.recent
        return l.length > 0 ? l[0] : null
    }
    // playing aún puede conservar el valor del player anterior durante esta señal.
    onActiveChanged: {
        if (root.active && root.active.isPlaying) root.recent = root.active
        root._track()
    }

    /** ciclo manual entre players (dir ±1) — para el switcher del media surface. */
    function cycleManual(dir) {
        var l = root.list
        if (l.length <= 1) { root.manual = root.active; return }
        var cur = (root.manual && l.indexOf(root.manual) >= 0) ? root.manual : root.active
        var idx = cur ? l.indexOf(cur) : -1
        if (idx < 0) idx = 0
        var ni = ((idx + dir) % l.length + l.length) % l.length
        root.manual = l[ni]
    }

    readonly property bool has: root.active !== null
    readonly property bool playing: root.has && root.active.isPlaying
    onPlayingChanged: if (root.playing) root.recent = root.active
    readonly property bool live: root.playing
    // MPRIS position advances on read, but does not notify on each elapsed second.
    Timer {
        interval: 1000
        repeat: true
        running: root.live && root.active.positionSupported
        onTriggered: if (root.active) root.active.positionChanged()
    }

    // Zen/Firefox con YouTube: tras cambiar de vídeo alterna entre dos fuentes
    // con el mismo título, la real (posición + mpris:length) y otra sin duración
    // y con posición ≈0 (la vista previa de YouTube), hasta la siguiente pausa.
    // Sin lengthSupported, MprisPlayer.length devuelve la posición (anillo
    // lleno). Guardamos el último dato válido del vídeo (de Quickshell o leído
    // por D-Bus) y extrapolamos desde él mientras la fuente siga inválida.
    property var _anchorPlayer: null
    property string _anchorKey: ""
    property real _anchorLen: 0
    property real _anchorPos: 0
    property real _anchorAt: 0

    function _keyOf(p) { return p ? (p.trackTitle || "") + "::" + (p.trackArtist || "") : "" }
    function _valid(p) { return !!p && p.lengthSupported && isFinite(p.length) && p.length > 0 }
    function _anchored(p) { return !!p && p === root._anchorPlayer && root._anchorKey === root._keyOf(p) }
    function _anchor(p, pos, len) {
        root._anchorPlayer = p
        root._anchorKey = root._keyOf(p)
        root._anchorLen = len
        root._anchorPos = Math.max(0, Math.min(len, pos))
        root._anchorAt = Date.now()
    }
    function _anchorNow(p) {
        var rate = p.isPlaying ? (isFinite(p.rate) && p.rate > 0 ? p.rate : 1) : 0
        return Math.min(root._anchorLen, root._anchorPos + (Date.now() - root._anchorAt) / 1000 * rate)
    }

    function lengthOf(p) {
        if (root._valid(p)) return p.length
        return root._anchored(p) ? root._anchorLen : 0
    }
    function positionOf(p) {
        if (!p) return 0
        void p.position
        if (root._valid(p) || !root._anchored(p)) return Math.max(0, p.position || 0)
        return root._anchorNow(p)
    }
    function offsetFor(p) { return p ? root.positionOf(p) - Math.max(0, p.position || 0) : 0 }
    function progressOf(p) {
        var l = root.lengthOf(p)
        return l > 0 ? Math.max(0, Math.min(1, root.positionOf(p) / l)) : 0
    }

    // Mantiene el ancla: copia el estado válido de Quickshell, acepta seeks
    // reales mientras la fuente es inválida (la fantasma da ≈0) y pide lecturas.
    function _track() {
        var p = root.active
        if (!p) return
        if (root._valid(p)) { root._anchor(p, p.position || 0, p.length); return }
        if (!root._anchored(p)) return
        var raw = p.position || 0
        if (raw > 1 && Math.abs(raw - root._anchorNow(p)) > 1.5) root._anchor(p, raw, root._anchorLen)
    }

    Connections {
        target: root.active || null
        ignoreUnknownSignals: true
        function onPositionChanged() { root._track() }
        function onLengthChanged() { root._track() }
        function onLengthSupportedChanged() { root._track() }
        function onPostTrackChanged() { root._track(); probeDelay.interval = 500; probeDelay.restart() }
    }

    // Lecturas D-Bus sólo mientras la fuente es inválida: rápidas hasta anclar,
    // luego espaciadas para corregir deriva. playerctl da µs.
    Timer {
        id: probeDelay
        interval: 1500
        repeat: true
        running: root.playing && !!root.active && root.active.positionSupported && !root._valid(root.active)
        onRunningChanged: if (running) interval = 500
        onTriggered: {
            var p = root.active
            var name = p && p.dbusName ? p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "") : ""
            interval = root._anchored(p) ? 10000 : 1500
            if (!name || positionProbe.running) return
            positionProbe.target = p
            positionProbe.key = root._keyOf(p)
            positionProbe.command = ["playerctl", "-p", name, "metadata", "--format", "{{position}} {{mpris:length}}"]
            positionProbe.running = true
        }
    }

    Process {
        id: positionProbe
        property var target: null
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var p = positionProbe.target
                var parts = (text || "").trim().split(/\s+/)
                var pos = parseFloat(parts[0]) / 1e6
                var len = parseFloat(parts[1]) / 1e6
                if (p && p === root.active && positionProbe.key === root._keyOf(p)
                        && isFinite(len) && len > 0 && isFinite(pos) && pos >= 0) {
                    root._anchor(p, pos, len)
                    p.positionChanged()
                }
            }
        }
    }

    readonly property string title: root.has && root.active.trackTitle ? root.active.trackTitle : "Nothing playing"
    readonly property string artist: root.has ? (root.active.trackArtist || "") : ""
    // ---- cover pegajoso per-track (anti "lo sabía y lo olvidó") ----
    // Los navegadores (Firefox/Zen, YouTube) sueltan mpris:artUrl al arrancar la
    // reproducción real pese a haberlo mostrado en el preview/pausa — el cover en
    // la pill/surface cae al ♪ como si nunca lo hubiera sabido. Guardamos el
    // último arte no-vacío del track; si llega vacío para el MISMO título+artista
    // lo reusamos en vez de caer. Resetea al cambiar de track (no mezcla covers
    // entre videos) y al irse el player (has→false). _curArt = lo que el navegador
    // manda AHORA (puede ser ""); artUrl = sticky (la api pública de Pill/Surface).
    readonly property string trackKeyNoArt: root.has ? (root.title + "::" + root.artist) : ""
    readonly property string _curArt: root.has ? (root.active.trackArtUrl || "") : ""
    property string _artStash: ""
    property string _artStashKey: ""
    on_CurArtChanged: {
        if (root._curArt.length > 0) {
            root._artStash = root._curArt
            root._artStashKey = root.trackKeyNoArt
        }
    }
    // track cambió: el stash queda obsoleto → descartar (no mostrar cover del
    // video anterior mientras el nuevo aún no manda arte). Se repuebla al llegar.
    onTrackKeyNoArtChanged: {
        if (root._artStashKey !== root.trackKeyNoArt) {
            root._artStash = ""
            root._artStashKey = ""
        }
    }
    readonly property string artUrl: {
        if (!root.has) return ""
        if (root._curArt.length > 0) return root._curArt
        if (root._artStashKey === root.trackKeyNoArt && root._artStash.length > 0)
            return root._artStash
        return ""
    }
    readonly property var sourceInfo: MediaSource.describe(
        root.has ? root.active.identity : "",
        root.has ? root.active.desktopEntry : "",
        root.has ? root.active.dbusName : "",
        root.has && root.active.metadata ? root.active.metadata["xesam:url"] : "")
    readonly property bool isMusicSource: root.has && sourceInfo.music
    readonly property string serviceLabel: root.has ? sourceInfo.label : ""
    readonly property string serviceIcon: sourceInfo.icon.length > 0
        ? Quickshell.iconPath(sourceInfo.icon, true) : ""
    readonly property string trackKey: root.has ? (root.title + "::" + root.artist + "::" + (root.artUrl)) : ""
    readonly property var pickable: root.list
}
