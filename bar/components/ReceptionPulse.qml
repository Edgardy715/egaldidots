import QtQuick
import Qt5Compat.GraphicalEffects
import "../Singletons"

// A finite wash inside the existing material; it never transforms content.
Item {
    id: root
    property bool reduced: Flags.reduceMotion
    property color accent: Theme.accent
    property color secondary: Theme.accentAlt
    property real origin: 0.5
    property real progress: 1
    property int duration: Math.round(950 * Flags.motionScale)
    readonly property bool running: wave.running
    readonly property real envelope: Math.sin(Math.PI * progress) * (1 - progress * 0.55)
    visible: progress < 1 && !reduced
    Accessible.ignored: true

    function trigger(position) {
        if (!root.parent.visible || reduced) return
        if (wave.running) return
        origin = Math.max(0.08, Math.min(0.92, position))
        wave.stop()
        progress = 0
        wave.start()
    }
    function settle() { wave.stop(); progress = 1 }
    onReducedChanged: if (reduced) settle()
    onVisibleChanged: if (!visible && progress < 1) settle()
    NumberAnimation {
        id: wave
        target: root; property: "progress"; to: 1
        duration: root.duration
        easing.type: Easing.InOutSine
    }
    RadialGradient {
        anchors.fill: parent
        horizontalOffset: (root.origin - 0.5) * width
        verticalOffset: height * 0.48
        horizontalRadius: Math.max(30, width * (0.22 + 0.42 * root.progress))
        verticalRadius: Math.max(16, height * (0.28 + 0.30 * root.progress))
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.accent, 0.12 * root.envelope) }
            GradientStop { position: 0.38; color: Qt.alpha(root.secondary, 0.075 * root.envelope) }
            GradientStop { position: 0.68; color: Qt.alpha(root.accent, 0.025 * root.envelope) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
