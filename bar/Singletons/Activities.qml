pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool enabled: Config._effective.activities.enabled
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDir + "/isla/activity.sock"
    property bool initialized: false
    property bool directoryReady: false
    // Navigation intent is consumed by the existing focus/recording surface.
    property bool requestList: false
    property var list: []
    readonly property int count: list.length
    readonly property var primary: list.length ? list.slice().sort((a, b) => priority(b) - priority(a) || a.startedAt - b.startedAt)[0] : null
    readonly property bool hasLive: list.some(a => a.state === "running")
    readonly property bool publishing: publishTimer.running
    readonly property bool expiring: expiryTimer.running
    readonly property bool listening: server.active
    // Unpublished state never invalidates a drawing binding during an input burst.
    property var entries: Object.create(null)
    property int revision: 0
    property bool manualTime: false
    property double testNow: 0
    readonly property alias ipcEndpoint: ipc
    function now() { return manualTime ? testNow : Date.now() }
    function priority(a) { return a.state === "failed" ? 3 : a.state === "running" ? (a.progress >= 0 ? 2 : 1) : 0 }
    function initialize() {
        if (initialized) return
        initialized = true
        if (runtimeDir) prepare.running = true
    }
    function text(value, maximum) { return typeof value === "string" ? value.replace(/[\u0000-\u001f]/g, " ").slice(0, maximum) : "" }
    function validId(value) { return typeof value === "string" && /^[a-zA-Z0-9_.:-]{1,96}$/.test(value) }
    function ingest(line) {
        if (typeof line !== "string" || line.length > 8192) return false
        try { return dispatch(JSON.parse(line)) } catch (_) { return false }
    }
    function dispatch(message) {
        if (!enabled || !message || typeof message !== "object" || Array.isArray(message) || !validId(message.id)) return false
        const op = message.op, id = message.id
        if (!["start", "update", "end"].includes(op)) return false
        if (message.progress !== undefined && (typeof message.progress !== "number" || !isFinite(message.progress)
            || (message.progress !== -1 && (message.progress < 0 || message.progress > 1)))) return false
        for (const key of ["title", "subtitle", "icon", "source"])
            if (message[key] !== undefined && typeof message[key] !== "string") return false
        if (op === "end" && message.state !== "done" && message.state !== "failed") return false
        let item = entries[id]
        if (op === "start") {
            if (!text(message.title, 160).trim()) return false
            if (!item) {
                const items = Object.values(entries)
                if (items.length >= 8) {
                    // Completed entries cede first, then the oldest indeterminate job.
                    const candidate = items.filter(a => a.state !== "running").sort((a,b) => a.endedAt-b.endedAt)[0]
                        || items.filter(a => a.progress < 0).sort((a,b) => a.startedAt-b.startedAt)[0]
                    if (!candidate) return false
                    delete entries[candidate.id]
                }
            }
            item = {id: id, title: "", subtitle: "", icon: "work", progress: -1, state: "running", source: "", startedAt: now(), endedAt: 0}
        } else if (!item || item.state !== "running") return false
        else item = Object.assign({}, item)
        for (const key of ["title", "subtitle", "icon", "source"]) {
            if (message[key] !== undefined) item[key] = text(message[key], key === "subtitle" ? 320 : key === "title" ? 160 : 96)
        }
        if (message.progress !== undefined) item.progress = message.progress
        if (op === "end") {
            item.state = message.state; item.endedAt = now()
            if (item.state === "done") item.progress = 1
        }
        entries[id] = item
        schedule()
        return true
    }
    function schedule() { if (!publishTimer.running) publishTimer.start() }
    function publish() {
        publishTimer.stop()
        list = Object.values(entries).sort((a,b) => a.startedAt-b.startedAt)
        revision++
        armExpiry()
    }
    function armExpiry() {
        expiryTimer.stop()
        const times = Object.values(entries).filter(a => a.state !== "running").map(a => a.endedAt + (a.state === "done" ? 6000 : 10000))
        if (times.length && !manualTime) { expiryTimer.interval = Math.max(1, Math.min(...times) - now()); expiryTimer.start() }
    }
    function expire() {
        const time = now()
        let changed = false
        for (const a of Object.values(entries)) {
            if (a.state !== "running" && time >= a.endedAt + (a.state === "done" ? 6000 : 10000)) { delete entries[a.id]; changed = true }
        }
        if (changed) publish()
        else armExpiry()
    }
    function remove(id) {
        if (!entries[id]) return
        delete entries[id]; schedule()
    }
    function reset() {
        entries = Object.create(null); publishTimer.stop(); expiryTimer.stop(); list = []; requestList = false
    }
    function notification(message) {
        if (!enabled || !Config._effective.activities.fromNotifications) return false
        const value = message.hints?.value
        if (typeof value !== "number" || !isFinite(value)) return false
        const id = "notification:" + message.id
        if (value >= 100 && entries[id]?.state === "done") return true
        const data = {id: id, title: message.summary || message.appName || I18n.tr("Actividad"), subtitle: message.body || "",
            source: message.appName || "notification", icon: message.appIcon || "download", progress: Math.max(0, Math.min(100, value)) / 100}
        if (!entries[id] || entries[id].state !== "running") dispatch(Object.assign({op:"start"}, data))
        else dispatch(Object.assign({op:"update"}, data))
        if (value >= 100) dispatch({op:"end", id:id, state:"done"})
        return true
    }
    onEnabledChanged: if (!enabled) reset()
    Timer { id: publishTimer; interval: 34; repeat: false; onTriggered: root.publish() }
    Timer { id: expiryTimer; repeat: false; onTriggered: root.expire() }
    Process {
        id: prepare
        command: ["mkdir", "-p", "-m", "700", root.runtimeDir + "/isla"]
        onExited: (code, status) => root.directoryReady = code === 0 && status === 0
    }
    SocketServer {
        id: server
        path: root.socketPath
        active: root.initialized && root.directoryReady && root.enabled
        handler: Socket {
            parser: SplitParser { onRead: data => root.ingest(data) }
        }
    }
    IpcHandler {
        id: ipc
        target: "activity"
        function start(json: string): bool { return root.ipcMessage("start", json) }
        function update(json: string): bool { return root.ipcMessage("update", json) }
        function end(json: string): bool { return root.ipcMessage("end", json) }
    }
    function ipcMessage(op, json) {
        if (typeof json !== "string" || json.length > 8192) return false
        try { const message = JSON.parse(json); if (!message || Array.isArray(message) || typeof message !== "object") return false; message.op = op; return dispatch(message) }
        catch (_) { return false }
    }
}
