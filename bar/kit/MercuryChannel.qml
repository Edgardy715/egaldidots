import QtQuick
import "../Singletons"

// Pista del kit: relleno plano y translúcido, sin borde ni sombra interior.
// El acento sólo entra como `tint` suave; el relleno fuerte lo pinta el control.
Rectangle {
    id: channel
    property color tint: Theme.accent
    property real tintAmount: 0
    radius: height / 2
    color: Qt.alpha(Theme.foreground, Theme.dark ? 0.12 : 0.09)
    Rectangle {
        anchors.fill: parent
        radius: channel.radius
        color: channel.tint
        opacity: 0.14 * Math.max(0, Math.min(1, channel.tintAmount))
        visible: opacity > 0.005
    }
}
