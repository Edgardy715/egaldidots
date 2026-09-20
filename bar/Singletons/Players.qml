pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/**
 * Isla · Players. Wrapper lean de Quickshell.Services.Mpris (molde Ricelin
 * Players.qml): descarta playerctld (proxy), elige el activo (primero el que
 * sonando, sino el primero) y expone lo que MediaSurface lee: title/artist/
 * artUrl/playing/trackKey. `active` es por-objeto para sobrevivir churn de
 * metadata y caer cuando el proceso muere.
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
            if (all[i] && !isProxy(all[i])) out.push(all[i])
        return out
    }

    /** player fijado manualmente (por el switcher ‹› del MediaSurface), o null.
     *  Si está set y aún vive en `list` → tiene prioridad; si se fue, auto-cae. */
    property var manual: null

    readonly property var active: {
        var l = root.list
        if (root.manual && l.indexOf(root.manual) >= 0) return root.manual
        for (var i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i]
        return l.length > 0 ? l[0] : null
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
    readonly property bool live: root.playing
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
    readonly property string serviceLabel: root.has ? (root.active.identity || root.active.desktopEntry || "") : ""
    readonly property string trackKey: root.has ? (root.title + "::" + root.artist + "::" + (root.artUrl)) : ""
    readonly property var pickable: root.list
}
