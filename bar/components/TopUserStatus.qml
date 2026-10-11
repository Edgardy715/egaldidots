import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"

MotionButton {
    id: root
    property real s: 1
    property url avatarSource
    property string userName: ""
    width: 38 * s
    height: 38 * s
    padding: 0
    Accessible.name: qsTr("Cambiar foto de perfil")
    ToolTip {
        visible: root.hovered
        text: qsTr("Cambiar foto de perfil")
        delay: 250
        x: root.width - width
        y: root.height + 8
        padding: 10
        contentItem: Text {
            text: qsTr("Cambiar foto de perfil")
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.foreground
        }
        background: Rectangle {
            radius: 10
            color: Theme.cardTop
            border.color: Theme.border
        }
    }
    background: Rectangle {
        radius: width / 2
        color: Qt.alpha(Theme.accent, 0.08 + 0.12 * root.interaction.presence)
        border.color: Qt.alpha(Theme.foreground, 0.12 + 0.2 * root.interaction.presence)
        border.width: root.activeFocus ? 2 : 1
    }
    contentItem: UserAvatar {
        name: root.userName || "•"
        source: root.avatarSource
        border.width: 0
        color: "transparent"
    }
}
