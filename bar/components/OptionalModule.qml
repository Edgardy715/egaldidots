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
    // Extra recession owned by the composition (a surface holds attention); multiplies exposure.
    property real depth: 1
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
    opacity: exposure * depth
    // Composite the module as one group while translucent: per-item opacity would let the rail
    // glass show through its own selector. Padded so outer shadows are kept, not clipped.
    layer.enabled: visible && opacity < 0.999
    layer.sourceRect: Qt.rect(-12 * s, -12 * s, width + 24 * s, height + 24 * s)
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
