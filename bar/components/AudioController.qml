import QtQuick
import Quickshell.Io
import "AudioSnapshot.js" as AudioSnapshot
import "../Singletons"

Item {
    id: root

    property bool active: false
    property var outputs: []
    property var inputs: []
    property var playback: []
    property var recording: []
    property var cards: []
    property string defaultOutput: ""
    property string defaultInput: ""
    property bool ready: false
    property bool busy: false
    property string error: ""
    property var meterSources: []
    property var levels: ({})

    function request(action, args) {
        if (!root.active || !bridge.running) {
            root.error = I18n.tr("El controlador de audio no está activo.")
            return
        }
        if (action !== "meters") root.error = ""
        bridge.write(JSON.stringify({ action: action, args: args || {} }) + "\n")
    }

    function refresh() {
        root.request("refresh", {})
    }

    property string appliedLine: ""
    function apply(message) {
        root.outputs = message.outputs || []
        root.inputs = message.inputs || []
        root.playback = message.playback || []
        root.recording = message.recording || []
        root.cards = message.cards || []
        root.defaultOutput = message.defaultOutput || ""
        root.defaultInput = message.defaultInput || ""
    }
    function primeFromCache() {
        if (root.ready || !AudioSnapshot.line) return
        try {
            root.apply(JSON.parse(AudioSnapshot.line))
            root.appliedLine = AudioSnapshot.line
            root.ready = true
        } catch (e) {}
    }

    function receive(line) {
        try {
            const message = JSON.parse(line)
            if (message.type === "snapshot") {
                // An unchanged snapshot (the cached one, or a refresh) rebuilds nothing.
                if (line !== root.appliedLine) {
                    root.apply(message)
                    root.appliedLine = line
                    AudioSnapshot.line = line
                }
                root.ready = true
            } else if (message.type === "error") {
                root.error = message.message || I18n.tr("Error de audio desconocido.")
            } else if (message.type === "busy") {
                root.busy = !!message.value
            } else if (message.type === "levels") {
                root.levels = message.levels || {}
            }
        } catch (e) {
            root.error = I18n.tr("Respuesta de audio inválida: %1").arg(String(e))
        }
    }

    onActiveChanged: {
        if (active) {
            error = ""
            primeFromCache()
            bridge.running = true
        } else {
            restart.stop()
            meterTimer.stop()
            bridge.running = false
            ready = false
            busy = false
            levels = ({})
        }
    }

    onReadyChanged: if (active && ready) meterTimer.restart()
    onMeterSourcesChanged: if (active && ready) meterTimer.restart()
    Component.onCompleted: if (active) {
        primeFromCache()
        bridge.running = true
    }

    Process {
        id: bridge
        command: ["python3", Qt.resolvedUrl("../services/audio_bridge.py").toString().replace(/^file:\/\//, "")]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.receive(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => { if (line.trim()) root.error = line.trim() }
        }
        onExited: code => {
            root.ready = false
            root.busy = false
            if (root.active) {
                if (!root.error) root.error = I18n.tr("El controlador de audio terminó (código %1).").arg(code)
                restart.start()
            }
        }
    }

    Timer {
        id: meterTimer
        interval: 60
        onTriggered: root.request("meters", { sources: root.meterSources })
    }

    Timer {
        id: restart
        interval: 1500
        onTriggered: if (root.active) bridge.running = true
    }
}
