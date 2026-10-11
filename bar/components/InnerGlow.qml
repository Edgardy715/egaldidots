import QtQuick
import Qt5Compat.GraphicalEffects
import "../Singletons"

Item {
    id: root
    property color glowColor: Theme.accent
    property real focusX: 0.26
    property real focusY: 0.82
    visible: opacity > 0.005
    property real driftPhase: 0
    readonly property real driftX: Flags.reduceMotion ? 0 : Math.sin(driftPhase) * 0.06
    readonly property real driftY: Flags.reduceMotion ? 0 : (Math.cos(driftPhase) - 1) * 0.02

    FrameAnimation {
        running: root.visible && root.opacity > 0.005 && root.width > 0 && root.height > 0 && !Flags.reduceMotion
        onTriggered: root.driftPhase = (root.driftPhase
            + Math.min(frameTime, 0.05) * 1000 * Math.PI * 2 / (Motion.breathe * 4)) % (Math.PI * 2)
    }

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: (root.focusX + root.driftX - 0.5) * width
        verticalOffset: (root.focusY + root.driftY - 0.5) * height
        horizontalRadius: Math.min(width * 0.34, height * 1.4)
        verticalRadius: Math.min(height * 0.55, width * 0.28)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.glowColor, 0.38) }
            GradientStop { position: 0.45; color: Qt.alpha(root.glowColor, 0.12) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
