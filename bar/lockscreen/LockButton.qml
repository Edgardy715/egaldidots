import QtQuick
import QtQuick.Controls.Basic
import "../Singletons"
import "../components"

MotionButton {
    id: root
    property string iconName: ""
    property bool flatStyle: false
    property real unit: 1
    implicitWidth: 44 * unit
    implicitHeight: 44 * unit
    Accessible.name: text
    display: AbstractButton.IconOnly
    contentItem: MaterialIcon {
        interaction: root.interaction
        iconName: root.iconName
        font.pixelSize: 23 * root.unit
        color: Theme.iconPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.4
    }
    background: Rectangle {
        radius: height / 2
        color: root.down ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : root.hovered ? Qt.alpha(Theme.foreground, Theme.alphaWash) : root.flatStyle ? "transparent" : Qt.alpha(Theme.foreground, Theme.alphaSoft)
        border.color: root.activeFocus ? Theme.accent : root.flatStyle ? "transparent" : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.hover } }
    }
}
