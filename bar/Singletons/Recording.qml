pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The bridge owns only the capture launched by Isla; no idle status polling.
Singleton {
    id: root
    property bool observe: false
    property bool systemAudio: true
    property bool microphoneAudio: false
    property var snapshot: ({connected: false, phase: "offline", elapsedSeconds: 0, outputPath: "", error: "", setupRequired: false})
    property int countdown: 0
    property real countdownDeadline: 0
    property string localError: ""
    property bool dependencyMissing: false
    property bool uncertain: false
    property string pendingAction: ""
    property string lastOutputPath: ""
    readonly property bool connected: snapshot.connected === true
    readonly property string phase: countdown > 0 ? "countdown"
        : pendingAction === "start" ? "starting" : pendingAction === "stop" ? "stopping" : snapshot.phase || "offline"
    readonly property bool active: phase === "recording" || phase === "paused" || phase === "stopping"
    readonly property bool engaged: uncertain || active || phase === "countdown" || phase === "starting"
    readonly property bool paused: phase === "paused"
    readonly property bool busy: pendingAction.length > 0 || phase === "starting" || phase === "stopping" || snapshot.busy === true
    readonly property bool pauseSupported: snapshot.pauseSupported !== false
    readonly property int elapsedSeconds: Math.max(0, Math.floor(snapshot.elapsedSeconds || 0))
    readonly property string outputPath: snapshot.outputPath || lastOutputPath
    readonly property string error: localError || (uncertain ? qsTr("Se perdió el control del grabador. Comprueba el archivo antes de volver a grabar.") : snapshot.error || "")
    readonly property bool setupRequired: snapshot.setupRequired === true
    readonly property string timeText: Math.floor(elapsedSeconds / 60).toString().padStart(2, "0")
        + ":" + String(elapsedSeconds % 60).padStart(2, "0")
    signal saved(string path)
    signal feedbackRequested(string kind)
    IpcHandler {
        target: "recording"
        function status(): string {
            return JSON.stringify({connected: root.connected, phase: root.phase, elapsedSeconds: root.elapsedSeconds,
                busy: root.busy, uncertain: root.uncertain, error: root.error, setupRequired: root.setupRequired})
        }
    }

    function send(action) {
        if (!observe || !bridge.running || !connected || busy) return false
        localError = ""
        pendingAction = action
        bridge.write(JSON.stringify({action: action, capture: "portal", audio: systemAudio ? microphoneAudio ? "both" : "system" : microphoneAudio ? "microphone" : "none"}) + "\n")
        return true
    }
    function start() {
        if (!connected || snapshot.phase !== "idle" || engaged || busy) return false
        localError = ""
        countdownDeadline = Date.now() + 3000
        countdown = 3
        return true
    }
    function cancelCountdown() { countdown = 0; countdownDeadline = 0 }
    function stop() {
        if (countdown > 0) { cancelCountdown(); return true }
        return active && send("stop")
    }
    function pause() { return phase === "recording" && pauseSupported && send("pause") }
    function resume() { return phase === "paused" && send("resume") }
    function refresh() {
        localError = ""
        dependencyMissing = false
        if (!bridge.running && observe) bridge.running = true
        else if (bridge.running) bridge.write(JSON.stringify({action: "refresh"}) + "\n")
    }
    function receive(line) {
        try {
            const message = JSON.parse(line)
            if (message.type === "state") {
                const wasConnected = connected
                const previousPhase = snapshot.phase
                const wasActive = active
                const wasPending = pendingAction === "start" || pendingAction === "stop"
                snapshot = message
                if (!message.busy) pendingAction = ""
                if (!connected) {
                    cancelCountdown()
                    if (wasActive || wasPending) uncertain = true
                } else if (message.phase === "idle" || message.phase === "recording" || message.phase === "paused") uncertain = false
                if (message.phase !== "idle") cancelCountdown()
                if (wasConnected && message.phase === "recording" && previousPhase !== "recording")
                    feedbackRequested("received")
            } else if (message.type === "saved" && typeof message.outputPath === "string" && message.outputPath.startsWith("/")) {
                lastOutputPath = message.outputPath
                saved(message.outputPath)
            }
        } catch (error) { root.localError = qsTr("No se pudo leer el estado del grabador.") }
    }
    onObserveChanged: if (!observe) {
        cancelCountdown()
        pendingAction = ""
        retry.stop()
        bridge.running = false
    } else if (!dependencyMissing) bridge.running = true

    Timer {
        interval: 250
        running: root.countdown > 0
        repeat: true
        onTriggered: {
            const remaining = Math.max(0, Math.ceil((root.countdownDeadline - Date.now()) / 1000))
            root.countdown = remaining
            if (remaining === 0) {
                root.countdownDeadline = 0
                root.send("start")
            }
        }
    }
    Process {
        id: bridge
        command: ["python3", Qt.resolvedUrl("../services/gpu_recording.py").toString().replace(/^file:\/\//, "")]
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: line => root.receive(line) }
        onExited: code => {
            root.cancelCountdown()
            if (root.active || root.pendingAction === "start" || root.pendingAction === "stop") root.uncertain = true
            root.pendingAction = ""
            root.snapshot = Object.assign({}, root.snapshot, {connected: false, phase: "offline", busy: false})
            root.dependencyMissing = code === 78
            if (root.observe && !root.dependencyMissing) retry.restart()
        }
    }
    Timer { id: retry; interval: 3000; onTriggered: if (root.observe && !root.dependencyMissing) bridge.running = true }
}
