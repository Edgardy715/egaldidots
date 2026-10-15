pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Wpscan

Singleton {
    id: root

    readonly property string wallDir: Config.wallpaperDir
    readonly property string cacheDir: Config.wallpaperCacheDir

    property var list: []
    property string current: ""
    readonly property int count: list.length
    property bool scanning: false
    property bool applying: false
    property string applyPhase: ""
    property string applyingPath: ""
    property string lastAttemptPath: ""
    property string applyError: ""
    property var pendingThumbs: ({})
    property var colorIndex: ({})
    property bool appliedInSession: false

    readonly property string applyScript: Config.wallpaperApplyScript

    readonly property int thumbW: 320
    readonly property int thumbH: 180
    readonly property int thumbQ: 78

    signal thumbUpdated(string path, string thumbSource, int cacheRevision)
    signal thumbFailed(string path)
    signal applyFinished(string path, bool success)
    signal transitionHandoff()

    function fileSource(path, revision) {
        const source = "file://" + String(path).split("/").map(encodeURIComponent).join("/")
        return revision ? source + "?v=" + revision : source
    }

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
        lastAttemptPath = applyingPath
        applyError = ""
        feedbackHold.stop()
        applyPhase = "preparing"
        applying = true
        const command = ["bash", applyScript, applyingPath, "--isla-feedback"]
        if (Flags.reduceMotion) command.push("--reduce-motion")
        applyProc.exec(command)
        return true
    }

    function forceRefresh(): void {
        scanning = true
        scanner.startScan(wallDir, cacheDir, thumbW, thumbH, thumbQ)
    }

    function requestThumbnail(path, thumbPath): void {
        var item = null
        for (var i = 0; i < list.length; i++) {
            if (list[i].path === path) { item = list[i]; break }
        }
        if (!item || item.thumbReady || item.thumb !== thumbPath || pendingThumbs[path] === thumbPath) return
        pendingThumbs[path] = thumbPath
        scanner.generateThumb(path, thumbPath, thumbW, thumbH, thumbQ)
    }

    Process {
        id: applyProc
        onExited: (exitCode, exitStatus) => {
            const path = root.applyingPath
            const success = exitCode === 0
            root.applying = false
            root.applyingPath = ""
            if (success || exitCode === 3) {
                root.appliedInSession = true
                root.current = path
            }
            if (exitCode === 3) root.applyError = "El fondo cambió, pero no se actualizaron los colores."
            else if (!success) root.applyError = "No se pudo aplicar el fondo. Comprueba Matugen y awww."
            root.applyPhase = success ? "done" : "error"
            feedbackHold.restart()
            root.applyFinished(path, success)
        }
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "ISLA_WALLPAPER_HANDOFF" && root.applying) {
                    root.applyPhase = "transition"
                    root.transitionHandoff()
                }
            }
        }
        stderr: StdioCollector {
            id: applyStderr
            onStreamFinished: if (applyStderr.text.length > 0)
                console.warn("[Wallpapers] " + applyStderr.text.trim())
        }
    }

    Timer {
        id: feedbackHold
        interval: root.applyPhase === "error" ? 3500 : 2000
        onTriggered: root.applyPhase = ""
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
            var previousByPath = ({})
            for (var j = 0; j < list.length; j++) previousByPath[list[j].path] = list[j]
            for (var i = 0; i < items.length; i++) {
                var w = items[i]
                var previous = previousByPath[w.path]
                if (previous && previous.thumb !== w.thumb) previous = null
                var revision = previous ? previous.cacheRevision : 0
                parsed.push({
                    path: w.path,
                    name: w.name,
                    baseName: w.baseName,
                    thumb: w.thumb,
                    thumbReady: w.thumbReady === true,
                    thumbSource: w.thumbReady ? root.fileSource(w.thumb, revision) : "",
                    cacheRevision: revision
                })
            }
            list = parsed
        }

        onScanFinished: {
            scanning = false
        }

        onThumbReady: function(sourcePath, cachePath, cacheAvailable, updated, errorString) {
            if (root.pendingThumbs[sourcePath] !== cachePath) return
            delete root.pendingThumbs[sourcePath]
            var item = null
            for (var i = 0; i < list.length; i++) {
                if (list[i].path === sourcePath && list[i].thumb === cachePath) {
                    item = list[i]
                    break
                }
            }
            if (!item) return
            if (!cacheAvailable) {
                root.thumbFailed(sourcePath)
                return
            }
            var rev = item.cacheRevision + 1
            item.thumbReady = true
            item.thumbSource = root.fileSource(cachePath, rev)
            item.cacheRevision = rev
            root.thumbUpdated(sourcePath, item.thumbSource, rev)
        }

        Component.onCompleted: {
            forceRefresh()
        }
    }

    Process {
        id: currentProc
        command: ["readlink", "-f", Config.cacheHome + "/matugen/current-wallpaper"]
        running: true
        stdout: StdioCollector {
            id: currentCollector
            onStreamFinished: {
                var v = (currentCollector.text || "").trim()
                if (v.length > 0 && !root.applying && !root.appliedInSession) current = v
            }
        }
    }
}
