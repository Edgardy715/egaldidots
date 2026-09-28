import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · Toggle. Interruptor iOS unificado (reemplaza las 3 copias en Utils/
 * Connectivity): track 40×24 con relleno acento, knob blanco 20×20 que se
 * desliza suavemente; compresión y retorno compartidos.
 *
 * Props:
 *   checked — estado (bind a la fuente de verdad externa)
 *   enabled — deshabilitado (opacidad baja, no clickable)
 * signal toggled(bool on)
 */
Item {
    id: root

    property string accessibleName: qsTr("Interruptor")
    property bool checked: false

    signal toggled(bool on)

    width: 40 * s
    height: 24 * s
    property real s: 1

    opacity: root.enabled ? 1 : 0.4

    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.checked: checked
    property bool keyboardDown: false
    Keys.onPressed: event => {
        if (event.isAutoRepeat || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = true; event.accepted = true
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat || !keyboardDown || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = false; toggled(!checked); event.accepted = true
    }
    onActiveFocusChanged: if (!activeFocus) keyboardDown = false
    onEnabledChanged: if (!enabled) keyboardDown = false
    Behavior on opacity { NumberAnimation { duration: Motion.hover } }
    InteractionMotion {
        id: response
        hovered: ma.containsMouse; pressed: root.keyboardDown || (ma.pressed && ma.containsMouse)
        focused: root.activeFocus; enabled: root.enabled; extent: 24
    }
    Rectangle {
        id: track
        scale: response.visualScale
        anchors.fill: parent
        radius: height / 2
        color: root.checked
            ? (ma.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaIconOnAcc) : Qt.alpha(Theme.accent, Theme.alphaIconSec))
            : (ma.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : Qt.alpha(Theme.foreground, Theme.alphaGlow))
        border.width: root.activeFocus ? 2 * Theme.borderHairline : Theme.borderHairline
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
            Behavior on x { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.hover; velocity: -1 } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
