import QtQuick
import "../Singletons"

// Quicksilver · canal hundido. Donde corre el mercurio: más oscuro que la
// tarjeta, con sombra interior arriba y un labio de luz abajo. Nunca se
// rellena de color tonal; el acento sólo entra como `tint` tenue.
Rectangle {
    id: channel
    property color tint: Theme.accent
    property real tintAmount: 0
    readonly property real depth: Theme.dark ? 0.30 : 0.07
    radius: height / 2
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha("#000000", channel.depth + 0.16) }
        GradientStop { position: 0.45; color: Qt.alpha("#000000", channel.depth) }
        GradientStop { position: 1; color: Qt.alpha("#000000", channel.depth * 0.7) }
    }
    border.width: 1
    border.color: Qt.alpha(Theme.dark ? "#ffffff" : "#000000", Theme.dark ? 0.06 : 0.08)
    Rectangle {
        anchors.fill: parent; anchors.margins: 1
        radius: Math.max(0, channel.radius - 1)
        color: channel.tint
        opacity: 0.2 * Math.max(0, Math.min(1, channel.tintAmount))
        visible: opacity > 0.005
    }
}
