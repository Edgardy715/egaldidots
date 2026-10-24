pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../Singletons"
import "../components"

Item {
    id: root
    required property PetRuntime runtime
    Accessible.ignored: true
    readonly property real response: runtime.profile === "playful" ? 1 : 0.6
    property real restAmount: runtime.sleeping ? 1 : 0
    onVisibleChanged: if (!visible) restMotion.complete()
    Connections {
        target: root.runtime
        function onMotionAllowedChanged() { if (!root.runtime.motionAllowed) restMotion.complete() }
        function onProfileChanged() { if (root.runtime.profile === "minimal") restMotion.complete() }
    }
    Behavior on restAmount {
        enabled: root.visible && root.runtime.motionAllowed && root.runtime.profile !== "minimal"
        SmoothedAnimation { id: restMotion; duration: Motion.standardLarge; velocity: -1 }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height * 0.8
            xScale: 1 + 0.06 * root.response * root.runtime.impulse + 0.025 * root.restAmount + 0.018 * root.runtime.breath
            yScale: 1 - 0.09 * root.response * root.runtime.impulse - 0.06 * root.restAmount + 0.025 * root.runtime.breath
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Theme.foreground
            startX: root.width * 0.14; startY: root.height * 0.85
            PathLine { x: root.width * 0.14; y: root.height * 0.46 }
            PathCubic { x: root.width * 0.86; y: root.height * 0.46; control1X: root.width * 0.14; control1Y: -root.height * 0.04; control2X: root.width * 0.86; control2Y: -root.height * 0.04 }
            PathLine { x: root.width * 0.86; y: root.height * 0.85 }
            PathQuad { x: root.width * 0.62; y: root.height * 0.85; controlX: root.width * 0.74; controlY: root.height * 0.68 }
            PathQuad { x: root.width * 0.38; y: root.height * 0.85; controlX: root.width * 0.5; controlY: root.height * 1.02 }
            PathQuad { x: root.width * 0.14; y: root.height * 0.85; controlX: root.width * 0.26; controlY: root.height * 0.68 }
        }
    }
    IslandCompanion {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (0.12 + 0.035 * root.restAmount)
        s: root.width / 36
        eyeColor: Theme.background
        reduced: !root.runtime.motionAllowed || root.runtime.profile === "minimal"
        mood: root.runtime.sleeping ? "paused" : root.runtime.reacting ? "received" : "rest"
        engaged: root.runtime.engaged
        lookX: root.runtime.lookX
        lookY: root.runtime.lookY
    }
}
