import QtQuick
import "../Singletons"

// Keep content alive through exit; Loader owns its lifetime afterwards.
Loader {
    id: root
    property bool requested: true
    property bool presented: true
    property bool animateChanges: true
    property real s: 1
    readonly property bool interactive: requested && presented && status === Loader.Ready
    property real exposure: 0
    property bool entering: false
    function retarget() {
        const destination = interactive ? 1 : 0
        reveal.stop()
        if (exposure === destination) return
        if (!animateChanges || Flags.reduceMotion) {
            exposure = destination
        } else {
            entering = destination === 1
            reveal.from = exposure
            reveal.to = destination
            reveal.start()
        }
    }
    onAnimateChangesChanged: retarget()
    onInteractiveChanged: retarget()
    Connections {
        target: Flags
        function onReduceMotionChanged() { root.retarget() }
    }
    active: requested || exposure > 0
    enabled: interactive
    visible: exposure > 0
    opacity: exposure
    scale: Flags.reduceMotion || !animateChanges ? 1 : 0.94 + 0.06 * exposure
    transformOrigin: Item.Top
    transform: Translate { y: Flags.reduceMotion || !root.animateChanges ? 0 : -6 * root.s * (1 - root.exposure) }
    NumberAnimation {
        id: reveal
        target: root
        property: "exposure"
        to: 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.entering ? Motion.emphasizedDecelCurve : Motion.emphasizedAccelCurve
        duration: root.entering ? Motion.emphasized : Motion.fast
    }
}
