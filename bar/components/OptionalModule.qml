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
    function retarget() {
        const destination = interactive ? 1 : 0
        reveal.stop()
        if (exposure === destination) return
        if (!animateChanges || Flags.reduceMotion) {
            exposure = destination
        } else {
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
    transform: Translate { y: -8 * root.s * (1 - root.exposure) }
    NumberAnimation {
        id: reveal
        target: root
        property: "exposure"
        to: 0
        easing.type: Motion.easeStandard
        duration: Motion.standardSmall
    }
}
