import QtQuick
import Qt5Compat.GraphicalEffects
import "../Singletons"

Item {
    id: root
    property color glowColor: Theme.accent
    property real focusX: 0.26
    property real focusY: 0.82
    visible: opacity > 0.005

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: (root.focusX - 0.5) * width
        verticalOffset: (root.focusY - 0.5) * height
        horizontalRadius: Math.min(width * 0.34, height * 1.4)
        verticalRadius: Math.min(height * 0.55, width * 0.28)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.glowColor, 0.38) }
            GradientStop { position: 0.45; color: Qt.alpha(root.glowColor, 0.12) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
