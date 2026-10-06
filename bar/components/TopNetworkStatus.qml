import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool connected: false
    signal activated()

    width: 19 * s
    height: 26 * s

    MaterialIcon {
        anchors.centerIn: parent
        iconName: root.connected ? Icons.iWifi : Icons.iWifiOff
        color: root.connected ? Theme.iconSecondary : Theme.iconMuted
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        interaction: wifiHit.motion
    }
    MotionArea {
        id: wifiHit
        anchors.fill: parent
        feedbackEnabled: false
        accessibleName: qsTr("Abrir conectividad")
        onClicked: root.activated()
    }
}
