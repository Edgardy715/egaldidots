import QtQuick
import Quickshell.Io

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
            root.error = qsTr("El controlador de audio no está activo.")
            return
        }
        if (action !== "meters") root.error = ""
        bridge.write(JSON.stringify({ action: action, args: args || {} }) + "\n")
    }

    function refresh() {
        root.request("refresh", {})
    }

    function receive(line) {
        try {
            const message = JSON.parse(line)
            if (message.type === "snapshot") {
                root.outputs = message.outputs || []
                root.inputs = message.inputs || []
                root.playback = message.playback || []
                root.recording = message.recording || []
                root.cards = message.cards || []
                root.defaultOutput = message.defaultOutput || ""
                root.defaultInput = message.defaultInput || ""
                root.ready = true
            } else if (message.type === "error") {
                root.error = message.message || qsTr("Error de audio desconocido.")
            } else if (message.type === "busy") {
                root.busy = !!message.value
            } else if (message.type === "levels") {
                root.levels = message.levels || {}
            }
        } catch (e) {
            root.error = qsTr("Respuesta de audio inválida: %1").arg(String(e))
        }
    }

    onActiveChanged: {
        if (active) {
            error = ""
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
    Component.onCompleted: if (active) bridge.running = true

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
                if (!root.error) root.error = qsTr("El controlador de audio terminó (código %1).").arg(code)
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
