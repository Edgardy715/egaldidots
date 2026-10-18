import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../Singletons"

/**
 * Isla · IconTile. Tile cuadrado de icono (reemplaza los ~5 duplicados en
 * Utils/Connectivity): rect 30×30 radius 9·s con wash acento + MaterialIcon.
 *
 * Props:
 *   iconName — glifo Material Symbols (ligadura)
 *   color    — color del icono (default accent)
 *   size     — lado del tile en px sin escalar (30)
 *   s        — escala del host
 */
Item {
    id: root

    property string iconName: ""
    property color color: Theme.accent
    property real size: 30
    property real s: 1
    property real radius: Theme.radiusMd * s
    property bool active: false

    width: size * s
    height: size * s
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Theme.accent, Theme.alphaGlow)
    }

    MaterialIcon {
        anchors.centerIn: parent
        iconName: root.iconName
        color: root.color
        font.pixelSize: Math.round(root.size * 0.55) * s
        layer.enabled: root.visible && root.active
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.accent, 0.7)
            shadowBlur: 0.7
            blurMax: 12
        }
    }
}
