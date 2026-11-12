import QtQuick
import QtQuick.Effects
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

    property string accessibleName: I18n.tr("Interruptor")
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
    Accessible.checkable: true
    Accessible.onPressAction: if (root.enabled && root.visible) root.toggled(!root.checked)
    Accessible.onToggleAction: if (root.enabled && root.visible) root.toggled(!root.checked)
    property bool keyboardDown: false
    Keys.onPressed: event => {
        if (!enabled || event.isAutoRepeat || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = true; event.accepted = true
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat || !keyboardDown || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = false; if (enabled) toggled(!checked); event.accepted = true
    }
    onActiveFocusChanged: if (!activeFocus) keyboardDown = false
    onEnabledChanged: if (!enabled) keyboardDown = false
    Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
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
            ? (Theme.liquid ? (ma.containsMouse ? Qt.lighter(Theme.stateFill, 1.08) : Theme.stateFill)
                : ma.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaIconOnAcc) : Qt.alpha(Theme.accent, Theme.alphaIconSec))
            : (ma.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : Qt.alpha(Theme.foreground, Theme.alphaGlow))
        border.width: root.activeFocus ? 2 * Theme.borderHairline : Theme.borderHairline
        border.color: root.checked
            ? Qt.alpha(Theme.accent, Theme.alphaCritical)
            : Qt.alpha(Theme.foreground, Theme.alphaHair)
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        gradient: Theme.liquid && root.checked ? trackVolume : null
        property Gradient trackVolume: Gradient {
            GradientStop { position: 0; color: Qt.lighter(track.color, 1.14) }
            GradientStop { position: 1; color: track.color }
        }

        Rectangle {
            id: knob
            readonly property real diameter: parent.height - 4 * s
            // Posición del centro de masa; con Superficies líquidas el botón se
            // alarga hacia su destino mientras viaja y se recoge al llegar.
            property real travel: root.checked ? parent.width - diameter - 2 * s : 2 * s
            Behavior on travel { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Theme.liquid ? Motion.standardSmall : Motion.hover; velocity: -1 } }
            readonly property real target: root.checked ? parent.width - diameter - 2 * s : 2 * s
            readonly property real stretch: Theme.liquid ? Math.min(8 * s, Math.abs(target - travel) * 0.7) : 0
            width: diameter + stretch
            height: diameter
            radius: height / 2
            color: root.checked ? (Theme.liquid ? Theme.stateContent : Theme.primaryContent) : Theme.iconSecondary
            anchors.verticalCenter: parent.verticalCenter
            x: target > travel ? travel : travel - stretch
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
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
