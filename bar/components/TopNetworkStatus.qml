import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool connected: false
    property bool wired: false
    signal activated()

    width: 19 * s
    height: 26 * s

    MaterialIcon {
        anchors.centerIn: parent
        iconName: root.connected ? Icons.iWifi : root.wired ? "lan" : Icons.iWifiOff
        color: root.connected || root.wired ? Theme.iconSecondary : Theme.iconMuted
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        interaction: wifiHit.motion
    }
    MotionArea {
        id: wifiHit
        anchors.fill: parent
        feedbackEnabled: false
        accessibleName: I18n.tr("Abrir conectividad")
        onClicked: root.activated()
    }
}
