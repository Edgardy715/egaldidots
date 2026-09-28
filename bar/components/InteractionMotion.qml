import QtQuick
import "../Singletons"

// State supplied by the fixed hit target; only visual children use visualScale.
Item {
    id: root
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool expressive: false
    property real extent: 40
    readonly property bool engaged: enabled && (hovered || focused)
    property real presence: engaged ? 1 : 0
    property real pressure: enabled && pressed ? 1 : 0
    readonly property bool reduced: Flags.reduceMotion
    onReducedChanged: if (reduced) { compression.stop(); recovery.stop(); visualScale = targetScale }
    property real visualScale: 1
    readonly property real targetScale: !enabled || Flags.reduceMotion ? 1
        : pressed ? (expressive ? Motion.pressScaleExpressive : extent < 36 ? Motion.pressScaleSmall : Motion.pressScale)
        : 1
    onTargetScaleChanged: {
        compression.stop()
        recovery.stop()
        if (Flags.reduceMotion || !visible) { visualScale = targetScale; return }
        if (pressed) { compression.to = targetScale; compression.start() }
        else { recovery.to = targetScale; recovery.start() }
    }
    onVisibleChanged: if (!visible) { compression.stop(); recovery.stop(); hoverAnimation.complete(); pressureAnimation.complete(); visualScale = targetScale }
    Behavior on presence { enabled: root.visible; NumberAnimation { id: hoverAnimation; duration: Motion.hover; easing.type: Easing.OutCubic } }
    Behavior on pressure { enabled: root.visible; NumberAnimation { id: pressureAnimation; duration: Motion.press; easing.type: Easing.OutQuad } }
    NumberAnimation { id: compression; target: root; property: "visualScale"; duration: Motion.press; easing.type: Easing.OutCubic }
    SpringAnimation {
        id: recovery
        target: root; property: "visualScale"
        spring: Motion.controlSpring
        damping: Motion.controlDamping
        epsilon: 0.001
        mass: 0.4 * Flags.motionScale
    }
}
