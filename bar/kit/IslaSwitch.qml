import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"
import "../settings"

// Interruptor del kit: pista 52x30, pulgar con muelle, marca de estado.
Switch {
    property bool reducedMotion: false
    id: toggle
    focusPolicy: Qt.StrongFocus
    implicitWidth: 64; implicitHeight: 44
    indicator: Rectangle {
        id: track
        x: 6; y: (toggle.height - height) / 2
        implicitWidth: 52; implicitHeight: 30
        radius: height / 2
        scale: toggle.reducedMotion ? 1 : toggle.down ? 0.94 : 1
        Behavior on scale { enabled: toggle.visible && !toggle.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
        color: toggle.checked ? (Theme.liquid ? Theme.stateFill : Theme.accent) : Qt.alpha(Theme.foreground, 0.12)
        gradient: Theme.liquid && toggle.checked ? trackVolume : null
        property Gradient trackVolume: Gradient {
            GradientStop { position: 0; color: Theme.stateFillLight }
            GradientStop { position: 1; color: Theme.stateFill }
        }
        opacity: toggle.enabled ? 1 : 0.45
        border.width: Theme.liquid ? 0 : 1
        border.color: Qt.alpha(Theme.foreground, toggle.hovered ? 0.24 : 0.10)
        Behavior on color { enabled: toggle.visible; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.fast } }
        Behavior on border.color { enabled: toggle.visible; ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
            color: "transparent"; border.width: 2; border.color: Theme.accent
            opacity: toggle.activeFocus ? 0.35 : 0
            Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.hover } }
        }
        Rectangle {
            id: knob
            // Centro de masa del botón; con Superficies líquidas se
            // alarga hacia su destino mientras viaja y se recoge al llegar.
            readonly property real target: toggle.checked ? 26 : 4
            property real travel: target
            Behavior on travel { enabled: toggle.visible && !toggle.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: 0.7; epsilon: 0.01 } }
            readonly property real stretch: Theme.liquid ? Math.min(9, Math.abs(target - travel) * 0.8) : 0
            x: target > travel ? travel : travel - stretch
            y: 4
            width: 22 + stretch; height: 22; radius: 11
            color: toggle.checked ? (Theme.liquid ? Theme.stateContent : Theme.primaryContent) : Theme.foreground
            Behavior on color { enabled: toggle.visible; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            EdotsIcon {
                anchors.centerIn: parent; iconName: "check"; font.pixelSize: Theme.fontSizeBody
                color: Theme.liquid ? Theme.stateFill : Theme.accent; selected: toggle.checked
                controlHovered: toggle.hovered; controlPressed: toggle.down
                Accessible.ignored: true
                opacity: toggle.checked && knob.stretch < 2 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { enabled: toggle.visible; NumberAnimation { duration: Motion.fast } }
            }
        }
    }
}
