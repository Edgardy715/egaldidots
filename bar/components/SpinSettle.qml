import QtQuick
import "../Singletons"

// Busy spinner for an Item's `rotation`. On stop it settles to the next full
// turn (decelerating) and normalises to 0 instead of freezing at a mid angle.
QtObject {
    id: root
    required property Item target
    property bool running: false
    property int period: Motion.spinner
    property bool _on: false
    // True while the last turn decelerates: hosts keep the busy glyph until it
    // lands so the replacement icon never spins.
    readonly property bool settling: settle.running

    function _sync() {
        const want = running && !Flags.reduceMotion && period > 0
        if (want === _on) return
        _on = want
        if (want) {
            settle.stop()
            target.rotation = 0
            loop.restart()
        } else {
            loop.stop()
            const a = ((target.rotation % 360) + 360) % 360
            if (a < 0.5 || Motion.standard <= 0) { target.rotation = 0; return }
            settle.from = a
            settle.duration = Math.max(Motion.fast, Math.round(Motion.standard * (360 - a) / 180))
            settle.restart()
        }
    }
    onRunningChanged: _sync()
    onPeriodChanged: if (_on && loop.running) loop.restart()
    Component.onCompleted: _sync()

    property Connections _flags: Connections {
        target: Flags
        function onReduceMotionChanged() { root._sync() }
    }
    property NumberAnimation _loop: NumberAnimation {
        id: loop
        target: root.target; property: "rotation"
        from: 0; to: 360
        duration: root.period
        loops: Animation.Infinite
    }
    property SequentialAnimation _settle: SequentialAnimation {
        id: settle
        property real from: 0
        property int duration: 0
        NumberAnimation {
            target: root.target; property: "rotation"
            from: settle.from; to: 360
            duration: settle.duration
            easing.type: Motion.easeStandard
        }
        ScriptAction { script: root.target.rotation = 0 }
    }
}
