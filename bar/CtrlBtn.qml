import QtQuick
import QtQuick.Shapes
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
    property bool primary: false
    property bool dim: false
    property real s: 1
    property int size: 40
    property real iconSize: Math.round(size * 0.52)
    readonly property string transportPath: iconName === "pause"
        ? "M7 4 Q6 4 6 5 L6 19 Q6 20 7 20 L9 20 Q10 20 10 19 L10 5 Q10 4 9 4 Z M15 4 Q14 4 14 5 L14 19 Q14 20 15 20 L17 20 Q18 20 18 19 L18 5 Q18 4 17 4 Z"
        : iconName === "play_arrow" ? "M7 4 Q6 3.4 6 5 L6 19 Q6 20.6 7 20 L20 12.8 Q21 12 20 11.2 Z"
        : iconName === "skip_next" ? "M4 5 L4 19 L15 12 Z M17 5 L20 5 L20 19 L17 19 Z"
        : iconName === "skip_previous" ? "M20 5 L20 19 L9 12 Z M4 5 L7 5 L7 19 L4 19 Z" : ""
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
        color: root.primary ? Qt.alpha(Theme.foreground, hover.containsMouse ? 1 : 0.90) : root.active
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
        scale: hover.pressed ? 0.94 : hover.containsMouse && !root.dim ? 1.06 : 1.0
        transformOrigin: Item.Center
        Behavior on scale { Anim { type: Anim.FastEffects } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Shape {
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: root.iconSize * root.s / 24
            visible: root.transportPath.length > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: root.primary ? Theme.background : Theme.foreground
                PathSvg { path: root.transportPath }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.iconName
            fill: 1
            visible: root.iconName.length > 0 && root.transportPath.length === 0
            color: root.primary ? Theme.background : root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.pixelSize: root.iconSize * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            visible: root.iconName.length === 0
            color: root.primary ? Theme.background : root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.family: Theme.fontMono
            font.pixelSize: root.iconSize * root.s
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
