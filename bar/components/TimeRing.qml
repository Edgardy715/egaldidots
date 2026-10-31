import QtQuick
import QtQuick.Effects
import "../Singletons"

// Anillo de tiempo de Tidemark. Sesión activa: el arco sigue `progress` (trazo
// uniforme, sin cabeza). En espera respira con easeBreathe (sólo mientras está a la vista). Al
// completarse se cierra en color de señal con un único brillo. Presentación pura.
Item {
    id: root
    property real progress: 0
    property bool active: false
    property bool running: false
    property bool completed: false
    property real s: 1
    property real diameter: 44 * s
    property string iconName: "timer"
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property bool waiting: !active && !completed
    property real breath: 0.1
    readonly property real drawn: arc.shown
    property bool glowing: false
    implicitWidth: diameter
    implicitHeight: diameter
    Accessible.ignored: true

    SequentialAnimation on breath {
        running: root.waiting && root.exposed && !Flags.reduceMotion
        onRunningChanged: if (!running) root.breath = 0.1
        loops: Animation.Infinite
        NumberAnimation { to: 0.16; duration: Motion.heat / 2; easing.type: Motion.easeBreathe }
        NumberAnimation { to: 0.1; duration: Motion.heat / 2; easing.type: Motion.easeBreathe }
    }

    // Un solo brillo por cierre: el temporizador sólo existe mientras brilla.
    onCompletedChanged: {
        if (completed && exposed && !Flags.reduceMotion) { glowing = true; glowHold.restart() }
        else { glowing = false; glowHold.stop() }
    }
    onExposedChanged: if (!exposed) { glowing = false; glowHold.stop() }
    Timer { id: glowHold; interval: Math.max(1, Motion.strokeTideHold); onTriggered: root.glowing = false }

    Item {
        anchors.fill: parent
        layer.enabled: root.glowing
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.signalSuccess, Motion.strokeGlow)
            shadowBlur: 0.75
            blurMax: 16
        }
        LevelStroke {
            id: arc
            anchors.fill: parent
            shape: "arc"
            value: root.completed ? 1 : root.active ? root.progress : root.breath
            head: false
            color: root.completed ? Theme.signalSuccess : Theme.accent
            lineWidth: Math.max(1.5, root.diameter * Theme.strokeRing * 1.4)
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.completed ? "check" : root.iconName
            color: root.completed ? Theme.signalSuccess : Theme.iconSecondary
            font.pixelSize: root.diameter * 0.46
        }
    }
}
