import QtQuick
import "../"
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real level: 0
    property bool charging: false
    property bool chargePaused: false
    property string stateText: ""
    signal activated()

    width: 27 * s
    height: 26 * s

    BatteryIndicator {
        anchors.centerIn: parent
        s: root.s
        level: root.level
        charging: root.charging
        chargePaused: root.chargePaused
    }
    MotionArea {
        id: batteryHit
        anchors.fill: parent
        feedbackEnabled: false
        accessibleName: qsTr("Batería %1 %, %2. Abrir energía").arg(Math.round(root.level * 100))
            .arg(root.stateText)
        onClicked: root.activated()
    }
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.topMargin: 7 * root.s
        width: batteryTip.implicitWidth + 18 * root.s
        height: 25 * root.s
        radius: height / 2
        color: Qt.alpha(Theme.cardTop, 0.96)
        border.width: Theme.borderHairline
        border.color: Theme.border
        opacity: batteryHit.containsMouse || batteryHit.activeFocus ? 1 : 0
        visible: opacity > 0.01
        z: 10
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        Text {
            id: batteryTip
            anchors.centerIn: parent
            text: qsTr("%1 % · %2").arg(Math.round(root.level * 100)).arg(root.stateText)
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeLabel * root.s
        }
    }
}
