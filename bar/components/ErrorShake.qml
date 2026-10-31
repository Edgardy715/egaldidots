import QtQuick
import "../Singletons"

// Rejection as one decaying oscillation: full speed on the first frame, less
// amplitude each cycle and a landing on zero without a corrective last step.
// Consumers bind their Translate to `offset`; reduced motion never shakes.
Item {
    id: root
    property real amplitude: 6
    property real cycles: 2.5
    property real progress: 1
    readonly property real offset: progress >= 1 ? 0
        : amplitude * (1 - progress) * (1 - progress) * Math.sin(progress * cycles * 2 * Math.PI)
    readonly property bool running: oscillation.running
    function trigger() {
        if (Flags.reduceMotion) { stop(); return }
        oscillation.restart()
    }
    function stop() {
        oscillation.stop()
        progress = 1
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.stop() }
    }
    NumberAnimation {
        id: oscillation
        target: root; property: "progress"
        from: 0; to: 1
        duration: Motion.standardLarge
        easing.type: Easing.Linear
    }
}
