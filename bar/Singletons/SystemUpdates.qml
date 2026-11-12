pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "UpdateText.js" as UpdateText

Singleton {
    id: root
    property var result: ({})
    property bool initialized: false
    property bool portalRequested: false
    property string error: ""
    property string feedback: ""
    // "check" or "install"; installs run in a systemd unit and stream JSON phases.
    property string operation: ""
    property string installSource: ""
    property var progress: ({})
    property var outcomes: ({})
    property bool cancelling: false
    property bool gotResult: false
    property string lastNotice: ""
    property double lastNoticeAt: 0
    readonly property bool busy: operation !== ""
    readonly property bool installing: operation === "install"
    readonly property var sources: ["system", "aur", "flatpak", "shell"]
    readonly property int count: sources.reduce((sum, key) => sum + (result[key]?.count || 0), 0)
    readonly property string helper: Quickshell.shellDir + "/scripts/system-updates.py"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/isla"
    signal openRequested()

    function open() { portalRequested = true; openRequested() }
    function initialize() {
        if (initialized) return
        initialized = true
        prepare.running = true
        probe.running = true
        startup.start()
    }
    function refresh() {
        if (busy) return
        operation = "check"
        error = ""
        feedback = ""
        bridge.command = ["python3", helper, "check"]
        bridge.running = true
    }
    function installable(source) {
        const status = result[source]
        return sources.includes(source) && !!status && status.count > 0 && !status.error && !status.blocked
            && !(source === "shell" && status.dirty)
    }
    function install(source) {
        if (busy || !installable(source)) return
        const total = result[source].count
        begin(source, {phase: source === "system" || source === "aur" ? "auth" : "prepare", done: 0, total: total, cancellable: false})
        installer.command = ["python3", helper, "install", source, "--total", String(total)]
        installer.running = true
    }
    // Reattach after a shell restart: the unit keeps running on its own.
    function follow(source) {
        begin(source, {phase: "prepare", done: 0, total: 0, cancellable: false})
        installer.command = ["python3", helper, "follow", source]
        installer.running = true
    }
    function begin(source, initial) {
        Activities.dispatch({op: "start", id: "updates:" + source, title: I18n.tr("Actualizando %1").arg(source), icon: "system_update", source: "SystemUpdates"})
        operation = "install"
        installSource = source
        progress = initial
        cancelling = false
        gotResult = false
        error = ""
        feedback = ""
        const next = Object.assign({}, outcomes)
        delete next[source]
        outcomes = next
    }
    function cancel() {
        if (!installing || cancelling || !progress.cancellable) return
        cancelling = true
        feedback = ""
        canceller.command = ["python3", helper, "cancel", installSource]
        canceller.running = true
    }
    function handle(event) {
        if (!event || event.source !== installSource) return
        if (event.event === "phase") {
            progress = event
            Activities.dispatch({op: "update", id: "updates:" + event.source,
                progress: event.total > 0 ? event.done / event.total : -1, subtitle: event.phase || ""})
        }
        else if (event.event === "result") finish(event)
    }
    function finish(event) {
        Activities.dispatch({op: "end", id: "updates:" + event.source, state: event.result === "success" ? "done" : "failed", subtitle: UpdateText.outcome(event, event.source)})
        gotResult = true
        outcomes = Object.assign({}, outcomes, {[event.source]: event})
        if (event.result === "cancelled" || !Config.updates.notifications) return
        const ok = event.result === "success"
        Notifs.postLocal(ok ? I18n.tr("Actualización completada") : I18n.tr("La actualización no se completó"),
            UpdateText.outcome(event, event.source),
            [{identifier: "updates", text: I18n.tr("Ver actualizaciones"), invoke: function() { root.open() }}], "isla:updates")
    }
    function accept(data) {
        if (!data || !data.system || !data.shell) throw new Error(I18n.tr("Respuesta de actualizaciones inválida"))
        result = data
        const fingerprint = JSON.stringify(sources.map(key => [key, data[key]?.count || 0, data[key]?.packages || []]))
        if (!count || !Config.updates.notifications) return
        if (fingerprint === lastNotice && Date.now() - lastNoticeAt < 86400000) return
        lastNotice = fingerprint
        lastNoticeAt = Date.now()
        Notifs.postLocal(I18n.tr("Hay actualizaciones disponibles"),
            I18n.tr("%1 actualizaciones para tu equipo. Abre Actualizaciones en Edots para revisarlas.").arg(count),
            [{identifier: "updates", text: I18n.tr("Ver actualizaciones"), invoke: function() { root.open() }}], "isla:updates")
        if (noticeState.loaded) noticeState.setText(JSON.stringify({fingerprint: lastNotice, time: lastNoticeAt}))
    }
    Timer { id: startup; interval: 45000; onTriggered: if (Config.updates.enabled) root.refresh() }
    Timer { interval: 21600000; repeat: true; running: root.initialized && Config.loaded && Config.updates.enabled; onTriggered: root.refresh() }
    Process {
        id: prepare
        command: ["mkdir", "-p", root.stateDir]
        onExited: code => { if (code === 0) noticeState.path = root.stateDir + "/updates-notice.json" }
    }
    FileView {
        id: noticeState
        property bool loaded: false
        printErrors: false
        onLoaded: {
            try { const data = JSON.parse(text()); root.lastNotice = data.fingerprint || ""; root.lastNoticeAt = Number(data.time) || 0 } catch (e) {}
            loaded = true
        }
        onLoadFailed: loaded = true
    }
    Process {
        id: probe
        command: ["python3", root.helper, "status"]
        stdout: StdioCollector { id: probed }
        onExited: code => Qt.callLater(() => {
            try {
                const active = code === 0 ? JSON.parse(probed.text).active : ""
                if (active && !root.busy) root.follow(active)
            } catch (e) {}
        })
    }
    Process {
        id: bridge
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: code => Qt.callLater(() => {
            try {
                const data = output.text.trim() ? JSON.parse(output.text) : null
                if (code !== 0) throw new Error(UpdateText.checkError(data?.system?.error || "failed"))
                root.accept(data)
            } catch (e) {
                if (errors.text.trim()) console.warn("Isla updates:", errors.text.trim())
                root.error = e instanceof SyntaxError ? UpdateText.checkError("failed") : e.message
            }
            root.operation = ""
        })
    }
    Process {
        id: installer
        stdout: SplitParser {
            onRead: line => {
                try { root.handle(JSON.parse(line)) } catch (e) { console.warn("Isla updates: unreadable event", line) }
            }
        }
        stderr: StdioCollector { id: installErrors }
        onExited: code => Qt.callLater(() => {
            const source = root.installSource
            if (!root.gotResult && code !== 0) {
                console.warn("Isla updates:", installErrors.text.trim())
                root.finish({event: "result", source: source, result: "error", code: "failed", detail: installErrors.text.trim(),
                             snapshot: "", reboot: false, changed: 0})
            }
            const succeeded = root.outcomes[source]?.result === "success"
            root.operation = ""
            root.installSource = ""
            root.cancelling = false
            root.progress = ({})
            // A recheck shows what is still pending; Git updates reload the shell instead.
            if (succeeded && source !== "shell") root.refresh()
        })
    }
    Process {
        id: canceller
        stdout: StdioCollector { id: cancelOutput }
        onExited: code => Qt.callLater(() => {
            if (code === 0) return
            root.cancelling = false
            let reason = ""
            try { reason = JSON.parse(cancelOutput.text).reason } catch (e) {}
            if (root.installing) root.feedback = reason === "committed"
                ? I18n.tr("Ya no se puede cancelar: los cambios se están aplicando. Espera a que termine.")
                : I18n.tr("No se pudo cancelar la actualización.")
        })
    }
    IpcHandler {
        target: "updates"
        function check(): void { root.refresh() }
        function open(): void { root.open() }
        function install(source: string): void { root.install(source) }
        function cancel(): void { root.cancel() }
        function state(): string {
            return JSON.stringify({busy: root.busy, operation: root.operation, source: root.installSource, progress: root.progress,
                                   outcomes: root.outcomes, error: root.error, feedback: root.feedback, result: root.result})
        }
    }
}
