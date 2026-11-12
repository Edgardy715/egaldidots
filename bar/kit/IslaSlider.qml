import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

// Slider con estela: pista translúcida, relleno de acento en dos tonos y
// bolita blanca. Al apuntar la bolita crece; al arrastrar se estira en la
// dirección del movimiento y el relleno la persigue con retraso (estela);
// al soltar rebota y suelta un destello.
Slider {
    id: slider
    property bool reducedMotion: false
    readonly property bool animated: visible && !reducedMotion && !Flags.reduceMotion
    implicitHeight: 44
    focusPolicy: Qt.StrongFocus
    readonly property real trackHeight: hovered || pressed ? 10 : 8
    readonly property real beadSize: 20
    readonly property real headX: beadSize / 2 + visualPosition * (availableWidth - beadSize)
    // Recién montado no se anima: el diseño todavía está colocando el ancho.
    property bool settled: false
    Timer { interval: 150; running: true; onTriggered: slider.settled = true }
    readonly property bool gliding: animated && settled
    // Posición dibujada: sigue al valor con un muelle crítico. Al arrastrar es
    // rígido (~20 ms de retraso) y convierte los pasos enteros y el clic en la
    // pista en un deslizamiento corto; suelto o con cambios externos
    // (restablecer, teclado) se desliza en ~200 ms.
    KitSpring {
        id: head
        target: slider.headX
        animate: slider.gliding
        omega: slider.pressed ? 90 : 26
        zeta: slider.pressed ? 1 : 0.9
    }
    readonly property real shownX: head.value
    // Estela: el relleno persigue a la bolita con un muelle más blando, también
    // al soltar, para que nunca se recoloque de golpe.
    KitSpring {
        id: wake
        target: head.value
        animate: slider.gliding
        omega: 15
        zeta: 0.8
        epsilon: 0.2
    }
    readonly property real wakeX: wake.value
    onPressedChanged: if (!pressed && animated) release.restart()
    background: MercuryChannel {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: slider.trackHeight
        opacity: slider.enabled ? 1 : 0.5
        Behavior on height { enabled: slider.animated; SpringAnimation { spring: 5; damping: 0.35 } }
        Rectangle {
            objectName: "sliderThread"
            width: Math.max(height, Math.min(slider.shownX, slider.wakeX))
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: bead.inkAlt }
                GradientStop { position: 1; color: bead.ink }
            }
        }
    }
    handle: MercuryBead {
        id: bead
        // Goma: se estira hacia donde va el valor mientras la estela lo persigue.
        readonly property real lag: slider.animated ? Math.min(9, Math.abs(slider.shownX - slider.wakeX) * 0.45) : 0
        readonly property real grow: slider.hovered || slider.pressed ? 4 : 0
        property real squeeze: slider.pressed && slider.animated ? 1 : 0
        Behavior on squeeze { enabled: slider.animated; SpringAnimation { spring: 5; damping: 0.3 } }
        x: slider.leftPadding + slider.shownX - width / 2
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.beadSize + grow + 6 * squeeze + lag
        height: slider.beadSize + grow - 5 * squeeze - lag * 0.3
        Behavior on width { enabled: slider.animated && !slider.pressed; SpringAnimation { spring: 5; damping: 0.32 } }
        Behavior on height { enabled: slider.animated && !slider.pressed; SpringAnimation { spring: 5; damping: 0.32 } }
        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: slider.beadSize; height: width; radius: width / 2
            color: "transparent"; border.width: 2; border.color: bead.ink
            opacity: 0
            ParallelAnimation {
                id: release
                NumberAnimation { target: ring; property: "scale"; from: 1; to: 2; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.5; to: 0; duration: 420; easing.type: Easing.OutQuad }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: parent.height + 8; radius: height / 2
            color: "transparent"; border.width: 2; border.color: Theme.accent
            opacity: slider.activeFocus ? 0.5 : 0
            Behavior on opacity { enabled: slider.visible; NumberAnimation { duration: Motion.hover } }
        }
    }
}
