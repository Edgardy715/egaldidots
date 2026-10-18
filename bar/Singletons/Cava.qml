pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Spectrum.js" as Spectrum

/** Real audio spectrum. Cava emits explicit ASCII frames, consumed on demand. */
Singleton {
    id: root

    /** prende/apaga el proceso de cava (lo pide el MediaSurface). */
    property bool wanted: false

    // Una surface por monitor puede pedir CAVA. Un booleano directo haría que
    // cerrar una surface apagara el stream de otra, por eso contamos consumidores.
    property var consumers: ({})

    function setConsumer(id, active) {
        var next = Object.assign({}, root.consumers)
        if (active) next[id] = true
        else delete next[id]
        root.consumers = next
        root.wanted = Object.keys(next).length > 0
    }

    /** cava está instalado; `hasFrame` indica si el stream entrega datos. */
    property bool available: false

    /** nº de barras (= cava `bars`). */
    readonly property int bars: 24

    /** array plano 0..1, normalizado + envolvente. Lectura para la surface. */
    property var values: (function () {
        var a = []
        for (var i = 0; i < root.bars; i++) a.push(0)
        return a
    })()

    readonly property string playerIdentity: Players.active ? Players.active.identity : ""
    readonly property string playerDesktop: Players.active ? Players.active.desktopEntry : ""
    readonly property string playerBus: Players.active ? Players.active.dbusName : ""
    readonly property string playerKey: playerIdentity + "|" + playerDesktop + "|" + playerBus
    onPlayerKeyChanged: sourceRestart.restart()
    Timer { id: sourceRestart; interval: 150 }

    function reset() {
        root.hasFrame = false
        root.targets = []
        root.values = Array(root.bars).fill(0)
    }

    property bool hasFrame: false

    // ---- probe: ¿cava está instalado? ----
    // Al cargar el singleton Y de forma perezosa: si algo pide el viz (wanted=true)
    // pero el probe inicial dijo "no hay cava" (p.ej. lo instalaron tras el boot),
    // re-probea. Así instalar cava a mitad de sesión se levanta solo, sin reload.
    Process {
        id: probe
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && command -v parec >/dev/null 2>&1"]
        Component.onCompleted: probe.running = true
        onExited: (code) => root.available = (code === 0)
    }
    onWantedChanged: if (root.wanted && !root.available) probe.running = true

    // Capture only the selected player's stream. Unresolved identity stays silent.
    Process {
        id: stream
        running: root.wanted && root.available && !sourceRestart.running
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../services/cava_stream.py").toString().replace(/^file:\/\//, "")),
                  "--identity", root.playerIdentity, "--desktop", root.playerDesktop, "--bus", root.playerBus]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parseFrame(line)
        }
        onStarted: root.reset()
        onExited: root.reset()
    }

    // Audio frames set targets; one clock owns the envelope, independent of refresh rate.
    property var targets: []
    property double lastFrameAt: 0

    function parseFrame(line) {
        var frame = Spectrum.parse(line, root.bars)
        if (!frame) return
        root.targets = frame
        root.lastFrameAt = Date.now()
        root.hasFrame = true
    }

    FrameAnimation {
        running: root.wanted && root.hasFrame
        onTriggered: {
            var fresh = Date.now() - root.lastFrameAt < 250
            root.values = Spectrum.advance(root.values, fresh ? root.targets : [], frameTime)
        }
    }

    /** apaga todo (se llama implícitamente al cerrar QS; útil para hot-reload). */
    function stop() { root.wanted = false }
}
