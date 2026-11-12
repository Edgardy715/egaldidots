import QtQuick
import "../../Singletons"
import ".."

// Directional entry of a folder's content. `run()` makes the new listing enter shifted by at most
// Motion.filesNavTravel px (direction +1 = into a folder, from the right; -1 = up, from the left;
// 0 = a lateral jump, fade only) while it fades in. The owner applies `offset` (x translation) and
// `fade` (opacity) to the content; nothing here touches the views or the model.
//
// Interruptible: a run() during a transition keeps the current offset, velocity and opacity and the
// springs carry on from there (no extra push), so the content never jumps, never freezes and never
// reverses. Only an entry that starts from the invisible pose waits while `holding` (listing still
// loading), for at most Motion.filesNavHold ms; an interrupted one keeps moving.
// reduceMotion: no offset, a linear fade of Motion.fast. Inactive (window hidden): resolves to the
// final state at once and nothing integrates.
Item {
    id: root
    objectName: "navTransition"
    visible: false

    property bool active: true
    property bool holding: false
    property int direction: 1
    readonly property real travel: Motion.filesNavTravel
    // Applied values. The offset is clamped so a kick on an interrupted run never exceeds `travel`.
    readonly property real offset: Flags.reduceMotion ? 0 : Math.max(-travel, Math.min(travel, off.value))
    readonly property real fade: Flags.reduceMotion ? _reducedFade : Math.max(0, Math.min(1, alpha.value))
    readonly property bool running: off.integrating || alpha.integrating || reducedAnim.running
    readonly property real offsetVelocity: off.velocity   // px/s, for continuity tests
    property real _reducedFade: 1
    property bool _holdExpired: false
    property bool _fromRest: false   // the current entry started invisible: it may wait for the listing
    readonly property bool _paused: holding && _fromRest && !_holdExpired

    // fromSnapshot (optional): { offset, fade, velocity } pose to start from (state captured elsewhere).
    // Omitted: the current pose when a transition is running, the entry pose otherwise.
    function run(fromSnapshot) {
        const d = direction > 0 ? 1 : direction < 0 ? -1 : 0
        _holdExpired = false
        if (!active) { _finish(); return }
        if (Flags.reduceMotion) {
            off.snap(0); alpha.snap(1)
            if (!reducedAnim.running) _reducedFade = 0   // a running fade continues from where it is
            reducedAnim.restart()
            return
        }
        if (fromSnapshot) {
            // Missing or non-numeric fields keep the current value (never NaN).
            const num = (v, fallback) => { const n = Number(v); return v !== undefined && v !== null && isFinite(n) ? n : fallback }
            off.value = Math.max(-travel, Math.min(travel, num(fromSnapshot.offset, off.value)))
            off.velocity = num(fromSnapshot.velocity, off.velocity)
            alpha.value = Math.max(0, Math.min(1, num(fromSnapshot.fade, alpha.value)))
            alpha.velocity = 0
            _fromRest = alpha.value < 0.02
        } else if (!running || alpha.value < 0.02) {
            off.snap(d * travel)          // invisible until it fades in: re-posing it cannot be seen
            alpha.snap(0)
            _fromRest = true
        } else {
            // Interrupted: keep position and velocity and keep integrating (no hold, no push): the
            // critically damped offset carries on towards 0 without reversing.
            _fromRest = false
        }
        off.retarget()
        alpha.retarget()
    }
    function _finish() {
        reducedAnim.stop()
        _reducedFade = 1
        off.snap(0)
        alpha.snap(1)
    }
    onActiveChanged: if (!active) _finish()
    Connections {
        target: Flags
        function onReduceMotionChanged() { root._finish() }
    }

    SpringValue {
        id: off
        target: 0
        value: 0
        spring: Motion.filesNavSpring.offset
        active: root.active
        manualStep: root._paused
        maxStep: 1 / 30
        settleDistance: 0.05
        settleSpeed: 0.5
    }
    SpringValue {
        id: alpha
        target: 1
        value: 1
        spring: Motion.filesNavSpring.fade
        active: root.active
        manualStep: root._paused
        maxStep: 1 / 30
        settleDistance: 0.002
        settleSpeed: 0.02
    }
    NumberAnimation {
        id: reducedAnim
        target: root
        property: "_reducedFade"
        to: 1
        duration: Motion.fast
    }
    Timer {
        interval: Motion.filesNavHold
        running: root.holding && root.running && root.active && !root._holdExpired
        onTriggered: root._holdExpired = true
    }
}
