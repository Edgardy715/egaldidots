import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

// Slider Quicksilver: canal hundido fino, un hilo de cinabrio que corre por
// dentro y una gota de mercurio que lo arrastra. Al pulsar la gota se aplasta
// contra el canal; el hilo la sigue con un instante de retraso (estela).
Slider {
    id: slider
    property bool reducedMotion: false
    implicitHeight: 44
    focusPolicy: Qt.StrongFocus
    readonly property real trackHeight: hovered || pressed ? 10 : 8
    readonly property real beadSize: 20
    readonly property real headX: beadSize / 2 + visualPosition * (availableWidth - beadSize)
    // Estela: el hilo alcanza a la gota con un muelle corto (sólo al arrastrar).
    property real wakeX: headX
    Behavior on wakeX { enabled: slider.visible && slider.pressed && !slider.reducedMotion; SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.2 } }
    background: MercuryChannel {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: slider.trackHeight
        opacity: slider.enabled ? 1 : 0.5
        Behavior on height { enabled: slider.visible && !slider.reducedMotion; NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        Rectangle {
            objectName: "sliderThread"
            x: 2; y: 2
            width: Math.max(height, Math.min(slider.headX, slider.wakeX))
            height: parent.height - 4
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(bead.ink, 1.18) }
                GradientStop { position: 1; color: bead.ink }
            }
            opacity: 0.92
        }
    }
    handle: MercuryBead {
        id: bead
        readonly property real squeeze: slider.pressed && !slider.reducedMotion ? 1 : 0
        x: slider.leftPadding + slider.headX - width / 2
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.beadSize + 5 * squeeze
        height: slider.beadSize - 4 * squeeze
        Behavior on width { enabled: slider.visible && !slider.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
        Behavior on height { enabled: slider.visible && !slider.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
        tintAmount: slider.pressed ? 0.45 : 0.18
        Behavior on tintAmount { enabled: slider.visible && !slider.reducedMotion; NumberAnimation { duration: Motion.fast } }
        glint: slider.enabled ? 1 : 0.5
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: parent.height + 8; radius: height / 2
            color: "transparent"; border.width: 2; border.color: Theme.accent
            opacity: slider.activeFocus ? 0.5 : 0
            Behavior on opacity { enabled: slider.visible; NumberAnimation { duration: Motion.hover } }
        }
    }
}
