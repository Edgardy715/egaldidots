import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

// Interruptor con goma: pista translúcida y bolita blanca. Al cambiar, la
// bolita se estira hacia su destino, rebota al llegar y suelta un destello;
// el acento (dos tonos) llena la pista detrás de ella y aparece un punto
// dentro de la bolita. Al pulsar se aplasta.
Switch {
    property bool reducedMotion: false
    readonly property bool animated: visible && !reducedMotion && !Flags.reduceMotion
    id: toggle
    focusPolicy: Qt.StrongFocus
    implicitWidth: 64; implicitHeight: 44
    onCheckedChanged: if (animated) burst.restart()
    indicator: MercuryChannel {
        id: track
        x: 8; y: (toggle.height - height) / 2
        implicitWidth: 48; implicitHeight: 26
        opacity: toggle.enabled ? 1 : 0.45
        Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.fast } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
            color: "transparent"; border.width: 2; border.color: Theme.accent
            opacity: toggle.activeFocus ? 0.45 : 0
            Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.hover } }
        }
        // Estela de acento: llena la pista hasta el borde de la bolita.
        Rectangle {
            objectName: "switchThread"
            height: parent.height; radius: height / 2
            width: Math.min(parent.width, Math.max(height, knob.x + knob.width + 3))
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: knob.inkAlt }
                GradientStop { position: 1; color: knob.ink }
            }
            opacity: knob.fill
            visible: opacity > 0.01
        }
        // Destello: un anillo que sale de la bolita al cambiar de estado.
        Rectangle {
            id: ring
            width: knob.rest; height: width; radius: width / 2
            x: knob.x + knob.width / 2 - width / 2
            y: knob.y + knob.height / 2 - height / 2
            color: "transparent"
            border.width: 2
            border.color: toggle.checked ? knob.ink : Theme.foreground
            opacity: 0; scale: 1
            ParallelAnimation {
                id: burst
                NumberAnimation { target: ring; property: "scale"; from: 1; to: 2.1; duration: 460; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.55; to: 0; duration: 460; easing.type: Easing.OutQuad }
            }
        }
        MercuryBead {
            id: knob
            readonly property real rest: 20
            readonly property real target: toggle.checked ? track.width - rest - 3 : 3
            property real travel: target
            Behavior on travel { enabled: toggle.animated; SpringAnimation { spring: 4.2; damping: 0.38; epsilon: 0.01 } }
            readonly property real stretch: toggle.animated ? Math.min(14, Math.abs(target - travel) * 1.15) : 0
            property real squeeze: toggle.down && toggle.animated ? 6 : 0
            Behavior on squeeze { enabled: toggle.animated; SpringAnimation { spring: Motion.controlSpring; damping: 0.3 } }
            property real fill: toggle.checked ? 1 : 0
            Behavior on fill { enabled: toggle.animated; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
            width: rest + stretch + squeeze
            height: rest - stretch * 0.32 - squeeze * 0.45
            x: Math.max(1, Math.min(track.width - width - 1, (target > travel ? travel : travel - stretch) - squeeze / 2))
            y: (track.height - height) / 2
            scale: toggle.hovered && !toggle.down ? 1.06 : 1
            Behavior on scale { enabled: toggle.animated; SpringAnimation { spring: 5; damping: 0.3 } }
            // Punto interior: el estado se lee también en la bolita.
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: knob.inkAlt }
                    GradientStop { position: 1; color: knob.ink }
                }
                scale: toggle.checked ? 1 : 0
                Behavior on scale { enabled: toggle.animated; NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
            }
        }
    }
}
