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
        color: "#f8f8fa"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.4
    }
    background: Rectangle {
        radius: height / 2
        color: root.down ? "#55ffffff" : root.hovered ? "#38ffffff" : root.flatStyle ? "transparent" : "#20ffffff"
        border.color: root.activeFocus ? "#eeffffff" : root.flatStyle ? "transparent" : "#30ffffff"
        Behavior on color { ColorAnimation { duration: Motion.hover } }
    }
}
