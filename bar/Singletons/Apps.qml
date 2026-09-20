pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services/fzf.js" as Fzf
import "../services/fuzzysort.js" as Fuzzy

/**
 * Isla · Apps service. Reemplaza el AppDb (C++) de caelestia por JS puro:
 *
 *  - list: DesktopEntries.applications.values ( ApplicationsNoDisplay), filtrado por
 *    una lista de hidden (regexps) editable en ~/.config/quickshell/bar/launcher.json
 *  - Frecuencia persistida en ~/.local/state/quickshell/launcher.json (id→count).
 *    Los apps se ordenan: favourites > por frecuencia desc > alpha (si 0 freq)
 *  - search(text): búsqueda fuzzy (fuzzysort) sobre name+genericName+comment.
 *    Same shaper que caelestia: keys+weights + fuzzyPrepped.
 *  - launch(entry): entry.execute() + bumpFrequency(id).
 *
 * No usa sqlite: un JSON chico con poca frequência es despreciable.
 * Se recarga en hot-restart desde disco (FileView con watchChanges:true).
 */
Singleton {
    id: root

    // ---- lista base (DesktopEntries filtrado) ----
    // favouriteApps y hiddenApps son arrays de regexps (strings). Si la app .id
    // matchea cualquier regex de favouriteApps → pinta estrella + siempre tope.
    // Si matchea hiddenApps → no aparece en el listado (ej. "yad-" bots).
    property var favouriteApps: []
    property var hiddenApps: []
    property bool useFuzzy: false   // fuzzy (fuzzysort) vs plain fzf; default fzf

    // ---- frecuencia persistente ----
    // Una sola property serializable; bump es debounced via Timer (1s) para no
    // reescribir disco en cada Enter spam.
    property var freqMap: ({})

    // DesktopEntries.cargando es async (lee /usr/share/applications/* en el
    // QML engine's thread). El modelo entrega las apps de A UNA via la signal
    // valuesChanged del ObjectModel subyacente. Sin este _appsRev counter como
    // dependencia explícita del binding `list`, QML NUNCA recalcula el array
    // (no sigue .values.length — el acceso como constante cached, no bound).
    property int _appsRev: 0
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root._appsRev++ }
    }

    readonly property var list: {
        var _ = root._appsRev   // forzar dependencia reactiva
        var raw = DesktopEntries.applications ? DesktopEntries.applications.values : []
        var hide = root.hiddenApps || []
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var e = raw[i]
            if (root._matchesAny(e.id, hide)) continue
            out.push(e)
        }
        return out
    }

    // prepped para fuzzysort { _item, name, genericName, comment }
    readonly property var fuzzyPrepped: root.list.map(function(e) {
        return {
            _item: e,
            name: Fuzzy.prepare(e.name || ""),
            genericName: Fuzzy.prepare(e.genericName || ""),
            comment: Fuzzy.prepare(e.comment || "")
        }
    })

    // fzf Finder construido sobre la lista (selector = name) — reconstruido
    // cuando `list` cambia (es reactivo al _appsRev: cada valuesChanged del
    // DesktopEntries.ObjectModel). Costo: 56 builds pequeños; Fzf hashes la
    // lista entera cada vez (~0.5ms), irrelevante en el throughput del launcher.
    property var fzf: null
    function _rebuildFzf() {
        if (root.useFuzzy) { root.fzf = null; return }
        try {
            root.fzf = new Fzf.Finder(root.list, {
                selector: function(item) { return (item.name || "") + " " + (item.genericName || "") + " " + (item.comment || "") }
            })
        } catch (e) { root.fzf = null }
    }
    onListChanged: root._rebuildFzf()
    onUseFuzzyChanged: root._rebuildFzf()

    // ---- search: same shape que caelestia ----
    function search(text) {
        var s = (text || "").trim().replace(/\s+/g, " ")
        if (!s) return root.sorted()
        if (root.useFuzzy) {
            var keys = ["name", "genericName", "comment"]
            var weights = [0.6, 0.2, 0.2]
            var results = Fuzzy.go(s, root.fuzzyPrepped, {
                all: true,
                keys: keys,
                scoreFn: function(r) {
                    var v = 0
                    for (var i = 0; i < weights.length; i++) v += r[i].score * weights[i]
                    return v
                }
            }).map(function(r) { return r.obj._item })
            return results
        }
        return root.fzf.find(s).sort(function(a, b) {
            if (a.score === b.score) {
                var la = (a.item ? a.item.name : "").trim().length
                var lb = (b.item ? b.item.name : "").trim().length
                return la - lb
            }
            return b.score - a.score
        }).map(function(r) { return r.item })
    }

    /** Ordena resultado por freq + colocar favourites al frente. */
    function sorted(items) {
        var arr = (items || root.list).slice()
        arr.sort(function(a, b) {
            var fa = root._isFav(a.id) ? Number.MAX_SAFE_INTEGER : (root.freqMap[a.id] || 0)
            var fb = root._isFav(b.id) ? Number.MAX_SAFE_INTEGER : (root.freqMap[b.id] || 0)
            if (fa !== fb) return fb - fa
            return (a.name || "").localeCompare(b.name || "")
        })
        return arr
    }

    function _isFav(id) {
        return root._matchesAny(id, root.favouriteApps || [])
    }

    function _matchesAny(str, regexList) {
        if (!str || !regexList || !regexList.length) return false
        for (var i = 0; i < regexList.length; i++) {
            try {
                var re = new RegExp(regexList[i])
                if (re.test(str)) return true
            } catch (e) {}
        }
        return false
    }

    function launch(entry) {
        if (!entry) return
        root._bumpFreq(entry.id)
        try { entry.execute() } catch (e) { /* ignore */ }
    }

    function _bumpFreq(id) {
        if (!id || !id.length) return
        var freq = root.freqMap[id] || 0
        root.freqMap[id] = freq + 1
        root.freqMapChanged()   // trigger save
    }

    // ---- persistencia state ----
    readonly property string stateBase: {
        var x = Quickshell.env("XDG_STATE_HOME")
        return (x && x.length > 0) ? x : (Quickshell.env("HOME") + "/.local/state")
    }
    readonly property string stateDir: stateBase + "/quickshell"
    readonly property string stateFile: stateDir + "/launcher.json"

    onFreqMapChanged: saveTimer.restart()

    Timer {
        id: saveTimer
        interval: 1000; repeat: false
        onTriggered: {
            root._ensureStateDir()
            try {
                storage.setText(JSON.stringify({
                    freq: root.freqMap,
                    favouriteApps: root.favouriteApps,
                    hiddenApps: root.hiddenApps,
                    useFuzzy: root.useFuzzy
                }))
            } catch (e) {}
        }
    }

    FileView {
        id: storage
        watchChanges: false
        // silencio el warning "Read of launcher.json failed: File does not
        // exist" — onLoadFailed lo maneja creando el archivo si es la primera
        // corrida.
        printErrors: false
        path: root.stateFile
        onLoaded: {
            try {
                var data = JSON.parse(storage.text() || "{}")
                if (data && data.freq) root.freqMap = data.freq
                if (data && data.favouriteApps) root.favouriteApps = data.favouriteApps
                if (data && data.hiddenApps) root.hiddenApps = data.hiddenApps
                if (data && typeof data.useFuzzy !== "undefined") root.useFuzzy = data.useFuzzy
            } catch (e) {}
        }
        onLoadFailed: function(err) {
            // primera corrida: crea el archivo vacío y guarda defaults init
            if (err === FileViewError.FileNotFound) {
                root._ensureStateDir()
                // Usar Quickshell.execDetached para escribir el file en vez de
                // storage.setText — eso invocaría una op de save concurrente
                // con la op de read dropped, generando el warning
                // "got operation finished from dropped operation".
                var json = JSON.stringify({
                    freq: {}, favouriteApps: [], hiddenApps: [], useFuzzy: false
                })
                Quickshell.execDetached({
                    command: ["sh", "-c", "echo '" + json.replace(/'/g, "'\\''") + "' > \"" + root.stateFile + "\""]
                })
            }
        }
    }

    // crea el dir de state si no existe (lazy: al disparar saveTimer; evita
    // proceskiller si el dir está pero no writable, no romper el shell)
    function _ensureStateDir() {
        try {
            var df = Quickshell.env("HOME") + "/.local/state"
            // mkdir via execDetached: si el dir no existe, lo crea; idempotente.
            Quickshell.execDetached({ command: ["mkdir", "-p", root.stateDir] })
        } catch (e) {}
    }
    Component.onCompleted: {
        root._ensureStateDir()
        root._rebuildFzf()
    }
}
