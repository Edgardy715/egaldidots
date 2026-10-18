import QtQuick
import QtQuick.Controls.Basic
import "../../Singletons"
import ".."

MotionButton {
    id: root
    property string symbol: ""
    property bool selected: false
    property real s: 1
    implicitHeight: 36 * s
    implicitWidth: Math.max(36 * s, label.implicitWidth + (symbol ? 54 : 24) * s)
    padding: 8 * s
    hoverEnabled: true
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeBody * s
    Accessible.name: text || ToolTip.text
    background: Rectangle {
        radius: 10 * root.s
        color: Qt.alpha(root.selected ? Theme.accent : Theme.foreground,
                        root.down ? Theme.alphaWashStrong : root.selected ? Theme.alphaChip : root.hovered ? Theme.alphaWash : Theme.alphaFaint)
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 7 * root.s
            MaterialIcon {
                visible: root.symbol.length > 0
                width: 18 * root.s; height: width
                anchors.verticalCenter: parent.verticalCenter
                iconName: root.symbol
                font.pixelSize: 18 * root.s
                color: root.selected ? Theme.accent : Theme.foreground
                interaction: root.interaction
            }
            Text {
                id: label
                visible: text.length > 0
                text: root.text
                anchors.verticalCenter: parent.verticalCenter
                font: root.font
                color: root.selected ? Theme.accent : Theme.foreground
            }
        }
    }
    opacity: enabled ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
}
