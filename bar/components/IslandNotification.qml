import QtQuick
import "../Singletons"

/** Inline notification shown while the island has morphed to notification size. */
Item {
    id: root

    property var notification: null
    property real s: 1
    property real pillWidth: 380
    property real pillHeight: 72
    property real closeness: 0
    property real breath: 0
    property bool holding: false
    property bool iconResolved: false
    property string iconSource: ""

    width: pillWidth
    height: pillHeight
    opacity: closeness
    visible: opacity > 0.01
    clip: true
    scale: holding ? 1.0 + breath * 0.025 : 1.0
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXl * root.s
        visible: root.notification !== null

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * root.s
            height: 48 * root.s
            visible: root.notification && root.iconResolved

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 10 * root.s
                height: parent.height + 10 * root.s
                radius: width / 2
                color: root.notification?.isCritical ? Theme.accentStrong : Theme.accent
                opacity: root.breath * 0.15 + 0.04
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8 * root.s * (1 + root.breath * 0.5)
                height: parent.height + 8 * root.s * (1 + root.breath * 0.5)
                radius: width / 2
                color: "transparent"
                border.width: Theme.borderHairlineSoft * root.s
                border.color: root.notification?.isCritical
                    ? Qt.alpha(Theme.accentStrong, 0.25 + root.breath * 0.25)
                    : Qt.alpha(Theme.accent, 0.20 + root.breath * 0.25)
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
                border.color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
                border.width: Theme.borderHairlineSoft * root.s
                scale: 1.0 + root.breath * 0.06
                Behavior on scale { NumberAnimation { duration: 300 } }
            }
            Image {
                anchors.centerIn: parent
                width: 30 * root.s
                height: 30 * root.s
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * root.s
            height: 48 * root.s
            radius: width / 2
            visible: !root.notification || !root.iconResolved
            color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
            border.color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
            border.width: Theme.borderHairlineSoft * root.s
            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.notification
                    ? Icons.getNotifIcon(root.notification.summary, root.notification.urgency)
                    : Icons.iBell
                color: root.notification?.isCritical ? Theme.accentStrong : Theme.accent
                font.pixelSize: Theme.fontSizeIcon * root.s
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXs * root.s
            Text {
                text: root.notification?.appName ?? ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
                visible: text.length > 0
            }
            Text {
                text: root.notification?.summary ?? ""
                color: root.notification?.isCritical ? Theme.accent : Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
            }
            Text {
                text: root.notification?.body ?? ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
                visible: text.length > 0
            }
        }
    }
}
