import QtQuick
import "Singletons"
import "components"

/**
 * Isla · CtrlBtn. Botón circular de control parametrizable para el MediaSurface
 * (shuffle / prev / next / repeat / switcher ‹›). Mismo idioma hover que los ws
 * dots: wash acento + scale 1.08, todo BezierSpline (cero springs).
 *
 * Props:
 *   glyph  — carácter Nerd Font (mit-…) a mostrar.
 *   active — (toggle on) relleno acento sólido.
 *   dim    — no soportado por el player (opacidad baja, no clickable).
 *   size   — diámetro en px sin escalar (se ×`s`).
 *   s      — scale del host.
 * signal clicked().
 */
Item {
    id: root
    property string glyph: ""
    property string iconName: ""
    property string accessibleName: iconName.length > 0 ? iconName : glyph
    property bool active: false
    property bool dim: false
    property real s: 1
    property int size: 40
    signal clicked()

    width: size * s
    height: size * s
    opacity: dim ? 0.32 : 1
    activeFocusOnTab: !dim
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Keys.onReturnPressed: if (!root.dim) root.clicked()
    Keys.onSpacePressed: if (!root.dim) root.clicked()

    readonly property real diam: size * s

    Rectangle {
        anchors.centerIn: parent
        width: root.diam
        height: root.diam
        radius: height / 2
        color: root.active
               ? Qt.alpha(Theme.accent, hover.containsMouse ? 0.88 : 0.72)
               : (hover.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : "transparent")
        border.color: root.active ? Qt.alpha(Theme.accentSoft, Theme.alphaCritical)
                                  : Qt.alpha(Theme.foreground, hover.containsMouse ? 0.35 : 0.0)
        border.width: Theme.borderHairline
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.accent
            border.width: Theme.borderHairline
            visible: root.activeFocus
        }
        scale: hover.containsMouse && !root.dim ? 1.08 : 1.0
        transformOrigin: Item.Center
        Behavior on scale { Anim { type: Anim.FastEffects } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.iconName
            visible: root.iconName.length > 0
            color: root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.pixelSize: Math.round(root.size * 0.42) * s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            visible: root.iconName.length === 0
            color: root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.family: Theme.fontMono
            font.pixelSize: Math.round(root.size * 0.42) * s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !root.dim
        onClicked: if (!root.dim) root.clicked()
    }
}
