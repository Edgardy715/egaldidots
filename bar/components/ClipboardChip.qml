import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../Singletons"

MotionButton {
    id: root
    property real s: 1
    property bool selected: false
    property bool prominent: false
    property string iconName: ""
    property string helpText: ""
    padding: 8 * s
    leftPadding: text.length ? 12 * s : 9 * s
    rightPadding: leftPadding
    implicitWidth: Math.max(36 * s, contents.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 36 * s
    highlighted: selected
    property bool presented: false
    Component.onCompleted: presented = true
    opacity: presented ? (enabled ? 1 : 0.42) : 0
    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
    ToolTip.text: helpText
    ToolTip.visible: helpText.length > 0 && (hovered || activeFocus)
    ToolTip.delay: 650
    Accessible.name: text.length ? text : helpText
    background: Rectangle {
        radius: Math.min(Theme.radiusSm * root.s, height / 2)
        color: root.prominent ? Theme.accent : Qt.alpha(root.selected ? Theme.accent : Theme.foreground,
            root.selected ? Theme.alphaSelected : root.down ? Theme.alphaChip : root.hovered || root.activeFocus ? Theme.alphaSoft : Theme.alphaFaint)
        border.width: root.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover } }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.selected ? Math.min(18 * root.s, parent.width / 3) : 0
            height: 2 * root.s
            radius: height / 2
            color: Theme.accent
            opacity: root.selected && !root.prominent ? 1 : 0
            Behavior on width { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; velocity: -1 } }
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
        }
    }
    contentItem: RowLayout {
        id: contents
        spacing: 6 * root.s
        MaterialIcon {
            visible: root.iconName.length > 0
            iconName: root.iconName
            interaction: root.interaction
            font.pixelSize: 17 * root.s
            color: root.prominent ? Theme.primaryContent : root.selected ? Theme.accent : Theme.foreground
            Accessible.ignored: true
        }
        AnimatedLabel {
            Layout.fillWidth: true
            visible: root.text.length > 0
            value: root.text
            textFormat: Text.PlainText
            color: root.prominent ? Theme.primaryContent : Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeLabel * root.s
            font.weight: root.prominent || root.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
