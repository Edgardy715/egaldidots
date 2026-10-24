pragma ComponentBehavior: Bound
import QtQuick
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

    Image {
        id: body
        objectName: "petBody"
        anchors.fill: parent
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        // The contour is static; decode once per size/theme instead of retaining a path renderer.
        source: "data:image/svg+xml," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><path fill='"
            + Theme.foreground + "' d='M14 85 V46 C14 -4 86 -4 86 46 V85 Q74 68 62 85 Q50 102 38 85 Q26 68 14 85Z'/></svg>")
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height * 0.8
            xScale: 1 + 0.06 * root.response * root.runtime.impulse + 0.025 * root.restAmount + 0.018 * root.runtime.breath
            yScale: 1 - 0.09 * root.response * root.runtime.impulse - 0.06 * root.restAmount + 0.025 * root.runtime.breath
        }
        Rectangle {
            anchors.fill: parent
            visible: body.status === Image.Error
            color: Theme.foreground
            radius: width / 2
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
