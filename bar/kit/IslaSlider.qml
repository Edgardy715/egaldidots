import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

// Slider del kit: tubo líquido (o fino sin Superficies líquidas), menisco y botón flotante.
Slider {
    id: slider
    property bool reducedMotion: false
    implicitHeight: 44
    focusPolicy: Qt.StrongFocus
    // Con Superficies líquidas el carril es un tubo grueso: el relleno
    // nunca baja de una gota y el botón flota dentro de su extremo.
    readonly property real trackHeight: Theme.liquid ? (pressed ? 30 : hovered ? 28 : 26) : (hovered || pressed ? 7 : 5)
    readonly property real fillWidth: Theme.liquid ? Math.max(trackHeight, visualPosition * availableWidth) : visualPosition * availableWidth
    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: slider.trackHeight
        radius: height / 2
        Behavior on height { enabled: slider.visible && !slider.reducedMotion; NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.09 : 0.18)
        opacity: slider.enabled ? 1 : 0.5
        Rectangle {
            width: slider.fillWidth
            height: parent.height
            radius: parent.radius
            color: Theme.liquid ? Theme.stateFill : Theme.accent
            gradient: Theme.liquid ? fillVolume : null
            property Gradient fillVolume: Gradient {
                GradientStop { position: 0; color: Theme.stateFillLight }
                GradientStop { position: 1; color: Theme.stateFill }
            }
            // Menisco: brillo fino en la superficie del líquido.
            Rectangle {
                visible: Theme.liquid
                x: parent.radius * 0.6; y: 1
                width: Math.max(0, parent.width - 2 * x); height: 1
                color: Qt.alpha("#ffffff", 0.3)
            }
        }
    }
    handle: Rectangle {
        readonly property real size: Theme.liquid ? slider.trackHeight - (slider.pressed ? 10 : 12) : 20
        x: Theme.liquid ? slider.leftPadding + slider.fillWidth - slider.trackHeight / 2 - width / 2
                        : slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        scale: slider.reducedMotion || Theme.liquid ? 1 : slider.pressed ? 1.22 : 1
        Behavior on scale { enabled: !slider.reducedMotion && slider.visible; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
        width: size
        height: size
        radius: size / 2
        color: Theme.liquid ? Qt.alpha(Theme.stateContent, slider.pressed ? 0.9 : 0.72) : Theme.foreground
        border.width: Theme.liquid ? 0 : 1
        border.color: Qt.alpha(Theme.background, 0.15)
        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.liquid ? Theme.stateContent : Theme.accent
            opacity: slider.activeFocus ? 0.5 : 0
            Behavior on opacity { enabled: slider.visible; NumberAnimation { duration: Motion.hover } }
        }
        Rectangle {
            anchors.centerIn: parent; width: 6; height: 6; radius: 3
            color: Theme.liquid ? Theme.stateFill : Theme.background
            opacity: slider.pressed ? 0.65 : slider.hovered ? 0.25 : 0
            Behavior on opacity { enabled: slider.visible; NumberAnimation { duration: Motion.hover } }
        }
    }
}
