pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Wpscan

Singleton {
    id: root

    readonly property string wallDir: Quickshell.env("HOME") + "/Wallpapers"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpapers"

    property var list: []
    property string current: ""
    readonly property int count: list.length
    property bool scanning: false
    property bool applying: false
    property string applyingPath: ""
    property string applyError: ""
    property var pendingThumbs: ({})
    property var colorIndex: ({})

    readonly property string applyScript: Quickshell.env("HOME") + "/.config/hypr/scripts/apply-wallpaper.sh"

    readonly property int thumbW: 320
    readonly property int thumbH: 180
    readonly property int thumbQ: 78

    signal thumbUpdated(string path, string thumbSource, int cacheRevision)
    signal thumbFailed(string path)
    signal applyFinished(string path, bool success)

    function accentFor(path, fallback) {
        const name = String(path).split("/").pop()
        const item = colorIndex[name]
        if (!item || item.sat < 0.17 || item.val < 0.05) return fallback
        return Qt.hsva((item.hue || 0) / 360,
                       Math.max(0.48, item.sat || 0),
                       Math.max(0.70, item.val || 0), 1)
    }

    function setWallpaper(path): bool {
        if (!path || applying) return false
        applyingPath = String(path)
        applyError = ""
        applying = true
        applyProc.exec(["bash", applyScript, applyingPath])
        return true
    }

    function forceRefresh(): void {
        scanning = true
        scanner.startScan(wallDir, cacheDir, thumbW, thumbH, thumbQ)
    }

    function requestThumbnail(path, thumbPath): void {
        if (pendingThumbs[path]) return
        for (var i = 0; i < list.length; i++) {
            if (list[i].path === path && list[i].thumbReady) return
        }
        pendingThumbs[path] = true
        scanner.generateThumb(path, thumbPath, thumbW, thumbH, thumbQ)
    }

    Process {
        id: applyProc
        onExited: (exitCode, exitStatus) => {
            const path = root.applyingPath
            const success = exitCode === 0
            root.applying = false
            root.applyingPath = ""
            if (success || exitCode === 3) root.current = path
            if (exitCode === 3) root.applyError = "El fondo cambió, pero no se actualizaron los colores."
            else if (!success) root.applyError = "No se pudo aplicar el fondo. Comprueba awww."
            root.applyFinished(path, success)
        }
        stderr: StdioCollector {
            id: applyStderr
            onStreamFinished: if (applyStderr.text.length > 0)
                console.warn("[Wallpapers] " + applyStderr.text.trim())
        }
    }

    FileView {
        id: colorIndexFile
        path: Quickshell.env("HOME") + "/.cache/wall-picker/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colorIndex = JSON.parse(colorIndexFile.text()).entries || ({})
            } catch (e) {
                root.colorIndex = ({})
            }
        }
    }

    WallpaperScanner {
        id: scanner

        onScanDone: function(items) {
            var parsed = []
            for (var i = 0; i < items.length; i++) {
                var w = items[i]
                parsed.push({
                    path: w.path,
                    name: w.name,
                    baseName: w.baseName,
                    thumb: w.thumb,
                    thumbReady: w.thumbReady === true,
                    thumbSource: w.thumbReady ? ("file://" + encodeURI(w.thumb)) : "",
                    cacheRevision: 0
                })
            }
            list = parsed
        }

        onScanFinished: {
            scanning = false
        }

        onThumbReady: function(sourcePath, cachePath, cacheAvailable, updated, errorString) {
            delete root.pendingThumbs[sourcePath]
            if (!cacheAvailable) {
                root.thumbFailed(sourcePath)
                return
            }
            for (var i = 0; i < list.length; i++) {
                if (list[i].path === sourcePath) {
                    var rev = list[i].cacheRevision + 1
                    list[i].thumbReady = true
                    list[i].thumbSource = "file://" + encodeURI(cachePath) + "?v=" + rev
                    list[i].cacheRevision = rev
                    root.thumbUpdated(sourcePath, list[i].thumbSource, rev)
                    break
                }
            }
        }

        Component.onCompleted: {
            forceRefresh()
        }
    }

    Process {
        id: currentProc
        command: ["bash", "-c",
            "readlink -f ~/.cache/wal/current-wallpaper 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            id: currentCollector
            onStreamFinished: {
                var v = (currentCollector.text || "").trim()
                if (v.length > 0 && !root.applying) current = v
            }
        }
    }
}
