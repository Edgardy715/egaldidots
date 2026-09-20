import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · Toggle. Interruptor iOS unificado (reemplaza las 3 copias en Utils/
 * Connectivity): track 40×24 con relleno acento, knob blanco 20×20 que se
 * desliza con bounceCurve (BezierSpline, cero springs).
 *
 * Props:
 *   checked — estado (bind a la fuente de verdad externa)
 *   enabled — deshabilitado (opacidad baja, no clickable)
 * signal toggled(bool on)
 */
Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool on)

    width: 40 * s
    height: 24 * s
    property real s: 1

    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked
            ? (ma.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaIconOnAcc) : Qt.alpha(Theme.accent, Theme.alphaIconSec))
            : (ma.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : Qt.alpha(Theme.foreground, Theme.alphaGlow))
        border.width: Theme.borderHairline
        border.color: root.checked
            ? Qt.alpha(Theme.accent, Theme.alphaCritical)
            : Qt.alpha(Theme.foreground, Theme.alphaHair)
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        Rectangle {
            id: knob
            width: parent.height - 4 * s
            height: parent.height - 4 * s
            radius: width / 2
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 2 * s : 2 * s
            Behavior on x { Anim { type: Anim.FastSpatial; easing.bezierCurve: Motion.bounceCurve } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
