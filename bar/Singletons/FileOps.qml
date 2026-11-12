pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// File operation queue for the explorer. One FIFO of mutating jobs (copy, move, trash,
// rename, mkdir, undo); each job is one files_helper.py process fed a single JSON line on
// stdin and destroyed when it exits. Queries (conflicts, thumb) bypass the queue so they never
// wait behind a long copy. Reads no Config/Flags: tuning goes through properties.
Singleton {
    id: root

    // Overrides for tests: helper path (default ISLA_FILES_HELPER, else the bundled script) and
    // extra environment for the child processes (e.g. XDG_DATA_HOME for an isolated trash).
    property string helperPath: ""
    property var environment: ({})
    property string pythonPath: "python3"   // tests only: force a missing interpreter
    readonly property int maxThumbs: 3
    readonly property int undoLimit: 20

    readonly property bool busy: pending > 0
    readonly property real progress: _progress
    readonly property string current: _current
    readonly property bool canUndo: undoDepth > 0 && !busy

    signal finished(string op, bool ok, string message)
    signal itemFailed(string path, string error)

    property int pending: 0
    property int undoDepth: 0
    property real _progress: 0
    property string _current: ""
    property var _queue: []
    property var _active: null
    property var _undo: []
    property var _undoMeta: []       // parallel to _undo: {label, count} of the operation each entry reverts
    // What the newest undo() reverts: {label: "move"|"trash"|"rename", count}. Valid until the next undo().
    property var lastUndo: ({label: "", count: 0})
    property var _thumbQueue: []     // not started: {key, path, size, cbs}
    property var _thumbRunning: ({}) // key -> request
    property int _activeThumbs: 0    // read-only for tests
    property int _thumbSpawned: 0    // read-only for tests

    readonly property string _defaultHelper: {
        const envPath = Quickshell.env("ISLA_FILES_HELPER") || ""
        if (envPath.length) return envPath
        return decodeURIComponent(Qt.resolvedUrl("../services/files_helper.py").toString().replace(/^file:\/\//, ""))
    }

    // ---- public API -------------------------------------------------------

    // cb(names: list<string>, ok: bool): names that already exist in dest.
    function conflicts(sources, dest, cb) {
        _spawn({op: "conflicts", request: {sources: sources, dest: dest}, query: true,
            callback: (result, ok) => { if (cb) cb(ok && Array.isArray(result) ? result : [], ok) }})
    }
    function copy(sources, dest, policy) {
        _enqueue("copy", {sources: sources, dest: dest, conflict: policy || "skip"})
    }
    function move(sources, dest, policy) {
        _enqueue("move", {sources: sources, dest: dest, conflict: policy || "skip"})
    }
    function trash(paths) { _enqueue("trash", {paths: paths}) }
    function rename(path, name) { _enqueue("rename", {path: path, name: name}) }
    function mkdir(parent, name) { _enqueue("mkdir", {parent: parent, name: name}) }

    // Undoes the newest recorded operation. The entry is taken immediately, so repeated calls walk
    // back through the stack; it is dropped even if the inverse fails.
    function undo() {
        if (busy || _undo.length === 0) return false
        const entry = _undo[_undo.length - 1]
        _undo = _undo.slice(0, -1)
        lastUndo = _undoMeta[_undoMeta.length - 1] || {label: "", count: 0}
        _undoMeta = _undoMeta.slice(0, -1)
        undoDepth = _undo.length
        _enqueue("undo", entry, entry.op)
        return true
    }

    // Stops the running job (SIGTERM; the helper reports ok=false). Queued jobs stay queued.
    function cancel() {
        if (!_active || !_active.process) return
        _active.cancelled = true
        _active.process.signal(15)
    }

    // cb(path: string, ok: bool): FreeDesktop thumbnail png for a video, "" when unavailable.
    // At most maxThumbs helper processes at once; identical path+size requests share one process.
    function thumb(path, size, cb) {
        const key = path + "\u0000" + size
        const live = _thumbRunning[key] || _thumbQueue.find(r => r.key === key)
        if (live) { if (cb) live.cbs.push(cb); return }
        _thumbQueue = _thumbQueue.concat([{key: key, path: path, size: size, cbs: cb ? [cb] : []}])
        _pumpThumbs()
    }
    // Drops a thumb request that has not started yet; its callbacks are never called.
    function cancelThumb(path, size) {
        const key = path + "\u0000" + size
        _thumbQueue = _thumbQueue.filter(r => r.key !== key)
    }
    function _pumpThumbs() {
        while (_activeThumbs < maxThumbs && _thumbQueue.length > 0) {
            const req = _thumbQueue[0]
            _thumbQueue = _thumbQueue.slice(1)
            _thumbRunning[req.key] = req
            _activeThumbs++
            _thumbSpawned++
            _spawn({op: "thumb", request: {path: req.path, size: req.size}, query: true,
                callback: (result, ok) => {
                    const value = ok && typeof result === "string" ? result : ""
                    req.cbs.forEach(fn => fn(value, ok))
                },
                release: () => {
                    delete _thumbRunning[req.key]
                    _activeThumbs--
                    _pumpThumbs()
                }})
        }
    }

    // ---- queue ------------------------------------------------------------

    function _enqueue(label, request, helperOp) {
        _queue = _queue.concat([{label: label, op: helperOp || label, request: request, undoable: label !== "undo"}])
        pending = _queue.length + (_active ? 1 : 0)
        _pump()
    }

    function _pump() {
        if (_active || _queue.length === 0) return
        const job = _queue[0]
        _queue = _queue.slice(1)
        _active = job
        _progress = 0
        _current = ""
        _spawn(job)
    }

    function _helper() { return helperPath.length ? helperPath : _defaultHelper }

    function _spawn(job) {
        job.errors = []
        job.doneEvent = null
        job.cancelled = false
        job.stderr = ""
        job.started = false
        job.settled = false
        job.process = procComp.createObject(root, {job: job})
        if (!job.process) { _settle(job); return }
        job.process.running = true
    }

    function _onLine(job, line) {
        let event = null
        try { event = JSON.parse(line) } catch (e) { return }
        if (!event || typeof event !== "object") return
        if (event.event === "progress") {
            if (job.query) return
            _current = String(event.current || "")
            _progress = event.total > 0 ? Math.max(0, Math.min(1, event.done / event.total)) : 0
        } else if (event.event === "item_error") {
            job.errors.push({path: String(event.path || ""), error: String(event.error || "")})
            if (!job.query) itemFailed(String(event.path || ""), String(event.error || ""))
        } else if (event.event === "done") {
            job.doneEvent = event
        }
    }

    // Runs once per job, when its process has exited and all stdout has been read.
    function _settle(job) {
        if (job.settled) return
        job.settled = true
        const ev = job.doneEvent
        const ok = ev !== null && ev.ok === true
        let message = ""
        if (!ok) {
            if ((ev && ev.cancelled) || (!ev && job.cancelled)) message = I18n.tr("Operación cancelada")
            else if (!job.started) message = I18n.tr("No se pudo iniciar el ayudante de archivos")
            else if (job.errors.length) message = job.errors[0].path + ": " + job.errors[0].error
            else if (job.stderr.length) message = job.stderr
            else message = I18n.tr("El ayudante de archivos terminó sin responder")
        }
        if (job.query) {
            if (job.callback) job.callback(ev ? ev.result : null, ok)
            if (job.release) job.release()
            return
        }
        if (ev && ev.undo && job.undoable) {
            _undo = _undo.concat([ev.undo]).slice(-undoLimit)
            const n = Array.isArray(ev.undo.pairs) ? ev.undo.pairs.length : Array.isArray(ev.undo.entries) ? ev.undo.entries.length : 1
            _undoMeta = _undoMeta.concat([{label: job.label, count: n}]).slice(-undoLimit)
            undoDepth = _undo.length
        }
        if (ok) _progress = 1
        _active = null
        pending = _queue.length
        if (_queue.length === 0) _current = ""
        finished(job.label, ok, message)
        _pump()
    }

    Component {
        id: procComp
        Process {
            id: proc
            property var job: null
            stdinEnabled: true
            command: [root.pythonPath, root._helper(), job ? job.op : ""]
            environment: root.environment
            onStarted: { job.started = true; write(JSON.stringify(job.request) + "\n") }
            // A process that never started emits no exited(): settle here so the queue moves on.
            onRunningChanged: {
                if (running || !job || job.started) return
                // proc.destroy() runs before the deferred call: capture everything it needs now, because
                // `root` is resolved through the destroyed Process' context.
                const ops = root, failed = job
                Qt.callLater(() => { failed.process = null; ops._settle(failed) })
                proc.destroy()
            }
            stdout: SplitParser {
                onRead: line => root._onLine(proc.job, line)
            }
            stderr: SplitParser {
                onRead: line => { if (proc.job && line.length) proc.job.stderr = line }
            }
            onExited: {
                const ops = root, finishedJob = job
                // Let queued stdout reads land before settling.
                Qt.callLater(() => {
                    if (finishedJob) { finishedJob.process = null; ops._settle(finishedJob) }
                })
                proc.destroy()
            }
        }
    }
}
