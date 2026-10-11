import QtQuick
import QtQuick.Controls.Basic
import "../components"
import "../Singletons"

MotionButton {
    id: root
    expressive: true
    property string symbol: ""
    property bool accent: false
    function contrastInk(color) {
        const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        const luminance = 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
        return luminance > 0.179 ? "#000000" : "#ffffff"
    }
    readonly property color ink: !enabled ? Theme.iconMuted : accent ? contrastInk(background.color) : Theme.foreground
    implicitHeight: Math.max(44, Theme.fontSizeBodyLg * 1.5 + 18)
    implicitWidth: Math.max(44, label.implicitWidth + (symbol ? Theme.fontSizeHead + 44 : 40))
    font.family: Config.appearance.fontFamily
    font.pixelSize: Theme.fontSizeBodyLg
    background: Rectangle {
        radius: root.down ? 9 : 10
        Behavior on radius { enabled: !Flags.reduceMotion && root.visible; NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
        Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast } }
        color: !root.enabled ? Qt.alpha(Theme.foreground, Theme.alphaFaint)
            : root.accent ? root.down ? Theme.accentStrong : Theme.accent
            : root.down ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong)
            : root.hovered ? Qt.alpha(Theme.foreground, Theme.alphaWash)
            : Qt.alpha(Theme.foreground, Theme.alphaFaint)
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, root.accent ? Theme.alphaHairline : Theme.alphaGhost)
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
            color: "transparent"; border.width: 2
            border.color: root.accent ? Theme.foreground : Theme.accent
            opacity: root.activeFocus ? 0.85 : 0
            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
        }
    }
    contentItem: Row {
        spacing: 9
        leftPadding: root.text ? 16 : Math.max(0, (root.availableWidth - 18) / 2)
        EdotsIcon { visible: root.symbol !== ""; iconName: root.symbol; selected: root.accent; font.pixelSize: Theme.fontSizeHead; color: root.ink; interaction: root.interaction; anchors.verticalCenter: parent.verticalCenter; Accessible.ignored: true }
        Text { id: label; text: root.text; font: root.font; color: root.ink; anchors.verticalCenter: parent.verticalCenter; Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast } } }
    }
}
