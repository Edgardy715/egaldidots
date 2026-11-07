import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

// Interruptor Quicksilver: una gota de mercurio en un canal hundido.
// Apagado: plata a la izquierda. Encendido: la gota se tiñe de cinabrio y
// el canal toma un reflejo tenue. Al viajar se estira hacia su destino y se
// aplasta (squish); al pulsar se ensancha como una gota apretada.
Switch {
    property bool reducedMotion: false
    id: toggle
    focusPolicy: Qt.StrongFocus
    implicitWidth: 64; implicitHeight: 44
    indicator: MercuryChannel {
        id: track
        x: 8; y: (toggle.height - height) / 2
        implicitWidth: 48; implicitHeight: 26
        opacity: toggle.enabled ? 1 : 0.45
        tintAmount: knob.tintAmount
        Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.fast } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
            color: "transparent"; border.width: 2; border.color: Theme.accent
            opacity: toggle.activeFocus ? 0.45 : 0
            Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.hover } }
        }
        // Hilo de cinabrio: el mercurio deja rastro hasta donde ha llegado.
        Rectangle {
            objectName: "switchThread"
            x: 4; anchors.verticalCenter: parent.verticalCenter
            height: 4; radius: 2
            width: Math.max(0, knob.x + knob.width / 2 - x)
            color: knob.ink
            opacity: knob.tintAmount
            visible: opacity > 0.01
        }
        MercuryBead {
            id: knob
            readonly property real rest: 20
            readonly property real target: toggle.checked ? track.width - rest - 3 : 3
            property real travel: target
            Behavior on travel { enabled: toggle.visible && !toggle.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: 0.62; epsilon: 0.01 } }
            readonly property real stretch: toggle.reducedMotion ? 0 : Math.min(10, Math.abs(target - travel) * 0.9)
            property real squeeze: toggle.down && !toggle.reducedMotion ? 4 : 0
            Behavior on squeeze { enabled: toggle.visible && !toggle.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
            property real tintAmount: toggle.checked ? 1 : 0
            Behavior on tintAmount { enabled: toggle.visible && !toggle.reducedMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
            width: rest + stretch + squeeze
            height: rest - stretch * 0.28 - squeeze * 0.4
            x: Math.max(1, Math.min(track.width - width - 1, (target > travel ? travel : travel - stretch) - squeeze / 2))
            y: (track.height - height) / 2
            glint: toggle.hovered ? 1 : 0.85
        }
    }
}
