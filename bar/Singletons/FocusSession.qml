pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Temporary by design: restarting the shell discards the session.
    property var clock: () => Date.now()
    readonly property bool running: state.phase === "running"
    readonly property bool paused: state.phase === "paused"
    readonly property bool active: running || paused
    readonly property int durationSeconds: state.durationMs / 1000
    readonly property int remainingSeconds: Math.ceil(state.remainingMs / 1000)
    readonly property real progress: state.durationMs > 0 ? Math.max(0, Math.min(1, 1 - state.remainingMs / state.durationMs)) : 0

    signal finished()
    signal rejected(string reason)

    QtObject {
        id: state
        property string phase: "idle"
        property real durationMs: 0
        property real remainingMs: 0
        property real deadline: 0
    }

    function start(minutes): bool {
        if (typeof minutes !== "number" || !Number.isFinite(minutes) || Math.floor(minutes) !== minutes || minutes < 1 || minutes > 180) {
            root.rejected(qsTr("Elige una duración entre 1 y 180 minutos."))
            return false
        }
        state.durationMs = minutes * 60000
        state.remainingMs = state.durationMs
        state.deadline = root.clock() + state.durationMs
        state.phase = "running"
        return true
    }

    function refresh(): void {
        if (!root.running) return
        state.remainingMs = Math.max(0, Math.min(state.durationMs, state.deadline - root.clock()))
        if (state.remainingMs > 0) return
        state.phase = "idle"
        root.finished()
    }

    function pause(): bool {
        root.refresh()
        if (!root.running) return false
        state.phase = "paused"
        return true
    }

    function resume(): bool {
        if (!root.paused) return false
        state.deadline = root.clock() + state.remainingMs
        state.phase = "running"
        return true
    }

    function cancel(): bool {
        const wasActive = root.active
        state.phase = "idle"
        state.durationMs = 0
        state.remainingMs = 0
        state.deadline = 0
        return wasActive
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: root.refresh()
    }
}
