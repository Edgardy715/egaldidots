pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../Singletons"
import "../components"

Item {
    id: root
    required property PetRuntime runtime
    property string character: "ghost"
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
            scale: Qt.size(root.width / 100, root.height / 100)
            strokeWidth: -1
            fillColor: Theme.foreground
            PathSvg {
                path: root.character === "blob"
                    ? "M12 65 C6 40 26 20 45 25 C62 8 86 31 87 52 C103 72 81 91 53 88 C25 95 8 83 12 65 Z"
                    : root.character === "octopus"
                    ? "M20 58 C10 0 90 0 80 58 C95 64 98 84 85 88 Q77 89 73 76 Q75 98 61 92 Q55 90 55 78 Q53 97 43 92 Q37 89 39 77 Q28 99 19 88 Q14 82 20 72 Q3 86 6 72 Q8 61 20 58 Z"
                    : "M14 85 L14 46 C14 -4 86 -4 86 46 L86 85 Q74 68 62 85 Q50 102 38 85 Q26 68 14 85 Z"
            }
        }
    }
    Rectangle {
        visible: root.runtime.eating
        x: root.width * 0.43
        y: root.height * 0.60
        width: root.width * 0.14
        height: root.height * (0.035 + 0.055 * root.runtime.chew)
        radius: height / 2
        color: Theme.background
    }
    Rectangle {
        visible: root.runtime.eating
        x: root.width * 0.65
        y: root.height * (0.66 - 0.06 * root.runtime.chew)
        width: root.width * 0.13
        height: width
        radius: width * 0.35
        rotation: -15
        color: Theme.accent
    }
    IslandCompanion {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (0.12 + 0.035 * root.restAmount)
        s: root.width / 36
        eyeColor: Theme.background
        reduced: !root.runtime.motionAllowed || root.runtime.profile === "minimal"
        mood: root.runtime.sleeping || (root.runtime.resting && !root.runtime.eating) ? "paused" : (root.runtime.reacting || root.runtime.eating) ? "received" : "rest"
        engaged: root.runtime.engaged
        lookX: root.runtime.lookX
        lookY: root.runtime.lookY
    }
}
