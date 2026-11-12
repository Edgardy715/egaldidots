import QtQuick
import "../../Singletons"
import ".."

// Elastic selection box. `target` is the exact rectangle the selection logic uses; the box
// drawn here chases it with a Motion spring (four SpringValue, no timers, no shaders), so the
// edge follows the pointer with a short elastic lag. Nothing integrates while `active` is false:
// on release the box settles on the exact rectangle and fades out. With reduceMotion the springs
// resolve to the target and only the short fade remains. Parent it to the scrolled content.
Item {
    id: root
    objectName: "rubberBand"

    property rect target: Qt.rect(0, 0, 0, 0)
    property bool active: false
    // Fraction currently drawn (0 = hidden). Exposed for tests.
    property real fade: active ? 1 : 0
    readonly property rect shown: Qt.rect(sx.value, sy.value, Math.max(0, sw.value), Math.max(0, sh.value))
    readonly property bool animating: sx.integrating || sy.integrating || sw.integrating || sh.integrating

    function _snapAll() { sx.snap(root.target.x); sy.snap(root.target.y); sw.snap(root.target.width); sh.snap(root.target.height) }
    onActiveChanged: if (active) _snapAll()

    Behavior on fade {
        enabled: root.active || root.fade > 0
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    SpringValue { id: sx; spring: Motion.rubberBandSpring; active: root.active; target: root.target.x }
    SpringValue { id: sy; spring: Motion.rubberBandSpring; active: root.active; target: root.target.y }
    SpringValue { id: sw; spring: Motion.rubberBandSpring; active: root.active; target: root.target.width }
    SpringValue { id: sh; spring: Motion.rubberBandSpring; active: root.active; target: root.target.height }

    Rectangle {
        objectName: "rubberBandBox"
        visible: root.active || root.fade > 0.001
        opacity: root.fade
        z: 10
        x: root.shown.x; y: root.shown.y; width: root.shown.width; height: root.shown.height
        radius: Theme.radiusSm
        color: Qt.alpha(Theme.accent, Theme.alphaWash)
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
    }
}
