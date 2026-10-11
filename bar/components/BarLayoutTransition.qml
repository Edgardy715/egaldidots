import QtQuick
import "../Singletons"

// Withdraw content before changing its host; the existing pill motor owns the morph.
Item {
    id: root
    property bool requestedCompact: false
    property bool compact: requestedCompact
    property bool exitReady: false
    property bool settleReady: false
    property int phase: 0
    readonly property bool active: phase !== 0
    property bool initialized: false
    function retarget() {
        if (!initialized) return
        if (Flags.reduceMotion) {
            compact = requestedCompact
            phase = 0
        } else if (requestedCompact === compact) {
            if (phase === 1) phase = 0
        } else phase = 1
    }
    onRequestedCompactChanged: retarget()
    Connections {
        target: Flags
        function onReduceMotionChanged() { root.retarget() }
    }
    Component.onCompleted: {
        compact = requestedCompact
        initialized = true
    }
    Timer {
        interval: 16
        repeat: true
        running: root.active
        onTriggered: {
            if (root.phase === 1 && root.exitReady) {
                root.compact = root.requestedCompact
                root.phase = 2
            } else if (root.phase === 2 && root.settleReady) root.phase = 0
        }
    }
}
