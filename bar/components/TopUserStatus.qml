import QtQuick
import QtQuick.Effects
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
    Accessible.name: I18n.tr("Cambiar foto de perfil")
    ToolTip {
        visible: root.hovered
        text: I18n.tr("Cambiar foto de perfil")
        delay: 250
        x: root.width - width
        y: root.height + 8
        padding: 10
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.easeStandard } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.hover; easing.type: Motion.easeStandard } }
        contentItem: Text {
            text: I18n.tr("Cambiar foto de perfil")
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
        // Neutral hairline at rest (one accent in the bar); the accent answers hover/focus.
        color: Qt.alpha(Theme.foreground, 0.05)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Theme.accent, 0.14)
            opacity: root.interaction.presence
        }
        border.color: Qt.tint(Qt.alpha(Theme.foreground, 0.24), Qt.alpha(Theme.accent, 0.75 * root.interaction.presence))
        border.width: Math.round((root.activeFocus ? 2 : 1) * root.s)
    }
    contentItem: UserAvatar {
        name: root.userName || "•"
        source: root.avatarSource
        border.width: 0
        color: "transparent"
    }
}
