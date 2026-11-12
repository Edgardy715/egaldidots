import QtQuick
import Quickshell
import Quickshell.Io
import "../../windows"
import "PathUtil.js" as PathUtil

// Lifecycle of the explorer window: created on open, destroyed on close, one instance.
// open(path) answers synchronously (IPC needs a bool) WITHOUT reading any file:
//  - not absolute -> false;
//  - an existing folder (detected by a "<path>/" probe that never opens the target) -> opens now, true;
//  - otherwise its parent must be an existing folder, else false; then true is returned and an async
//    `test -e` decides: if the path exists the parent folder opens with it selected, if not nothing opens.
//    So a missing child of an existing folder answers true but opens no window (isla-files checks -e first).
Scope {
    id: host

    readonly property bool isOpen: loader.active
    readonly property string currentPath: loader.item ? loader.item.view.path : ""
    property string _folder: ""
    property string _name: ""
    property string _wanted: ""
    property int _probeSeq: 0
    property var _probeCache: null

    // Folder probe: Qt.createComponent("file://<dir>/") reports "File name case mismatch" for an
    // existing directory and "No such file" for a missing path or a non-directory, and never reads
    // or blocks on the target (FIFO or huge file safe). Each probe has a unique query so Qt's
    // component cache cannot answer stale. Messages are locale dependent, so the result is compared
    // with the message for a path that cannot exist.
    function isDir(path) {
        if (_probeCache === null) _probeCache = _probeMessage("/nonexistent-azog-probe-path")
        return _probeMessage(path) !== _probeCache
    }
    function _probeMessage(path) {
        const dir = path.charAt(path.length - 1) === "/" ? path : path + "/"
        const url = PathUtil.toUrl(dir) + "?probe=" + (++_probeSeq) + "-" + Math.random()
        const c = Qt.createComponent(url)
        const msg = String(c.errorString())
        c.destroy()
        const at = msg.indexOf(": ")
        return at >= 0 ? msg.slice(at + 2).trim() : msg.trim()
    }

    function open(path): bool {
        const p = PathUtil.normalize(String(path))
        if (!p.length || p.charAt(0) !== "/" || p.indexOf("\u0000") >= 0) return false
        if (isDir(p)) {
            _cancelProbe()
            _show(p, "")
            return true
        }
        const parent = PathUtil.parent(p)
        if (p === "/" || !isDir(parent)) return false
        _cancelProbe()
        _wanted = p
        const proc = probeComponent.createObject(host, { command: ["test", "-e", p] })
        if (!proc) { _wanted = ""; return false }
        proc.exited.connect(code => {
            if (host._wanted === p) {
                host._wanted = ""
                if (code === 0) host._show(parent, p.slice(p.lastIndexOf("/") + 1))
            }
            if (host._probe === proc) host._probe = null
            proc.destroy()
        })
        _probe = proc
        proc.running = true
        return true
    }
    property var _probe: null
    function _cancelProbe() {
        _wanted = ""
        if (_probe) { _probe.running = false; _probe = null }
    }
    function toggle(): bool {
        if (isOpen || _wanted.length) { close(); return true }
        return open(Quickshell.env("HOME") || "/")
    }
    function close(): bool {
        const was = loader.active || _wanted.length > 0
        _cancelProbe()
        loader.active = false
        return was
    }
    function _show(folder, name) {
        if (loader.active && loader.item) {
            loader.item.visible = true
            loader.item.openTarget(folder, name)
            return
        }
        _folder = folder
        _name = name
        loader.active = true
    }

    Component { id: probeComponent; Process {} }

    // Warm-up: a few seconds after the shell started, while nothing is open, one hidden FilesWindow is
    // built asynchronously (compiled type, fonts, first-use caches) and destroyed right after, so the
    // first real open skips that work. Never shown and never kept: its view is inactive (no folder poll),
    // lists "/" only, and nothing stays in memory once it is destroyed. Opening meanwhile is not delayed.
    property var _warmComponent: null
    property var _warmIncubator: null
    property bool warmed: false     // read-only for tests/measurements
    function _warm() {
        if (warmed || loader.active || _wanted.length > 0) return
        warmed = true
        const c = Qt.createComponent(Qt.resolvedUrl("../../windows/FilesWindow.qml"), Component.Asynchronous)
        _warmComponent = c
        const build = () => {
            if (c.status === Component.Error) { console.warn("files warm-up:", c.errorString()); _warmComponent = null; return }
            if (c.status !== Component.Ready) return
            const inc = c.incubateObject(host, { visible: false, startPath: "/" }, Qt.Asynchronous)
            if (!inc) { _warmComponent = null; return }
            _warmIncubator = inc
            const done = () => {
                if (inc.status === Component.Loading) return
                if (inc.status === Component.Ready && inc.object) inc.object.destroy()
                host._warmIncubator = null
                host._warmComponent = null
            }
            inc.onStatusChanged = done
            done()
        }
        if (c.status === Component.Loading) c.statusChanged.connect(build)
        else build()
    }
    Timer { interval: 3000; running: true; onTriggered: host._warm() }
    Loader {
        id: loader
        active: false
        sourceComponent: FilesWindow {
            startPath: host._folder
            selectName: host._name
            onCloseRequested: Qt.callLater(host.close)
        }
    }
}
