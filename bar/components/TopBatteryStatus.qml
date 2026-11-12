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
        accessibleName: I18n.tr("Batería %1 %, %2. Abrir energía").arg(Math.round(root.level * 100))
            .arg(root.stateText)
        onClicked: root.activated()
    }
    Rectangle {
        id: tip
        readonly property bool shown: batteryHit.containsMouse || batteryHit.activeFocus
        // La etiqueta cae 4 px desde la barra y crece desde su esquina, como un
        // globo que se despega del icono; al irse vuelve por el mismo camino.
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.topMargin: (Flags.reduceMotion || shown ? 7 : 3) * root.s
        Behavior on anchors.topMargin { SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
        transformOrigin: Item.TopRight
        scale: Flags.reduceMotion || shown ? 1 : 0.94
        Behavior on scale { SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
        width: batteryTip.implicitWidth + 18 * root.s
        Behavior on width { enabled: tip.visible && !Flags.reduceMotion; SmoothedAnimation { duration: Motion.fast; velocity: -1 } }
        height: 25 * root.s
        radius: height / 2
        color: Qt.alpha(Theme.cardTop, 0.96)
        border.width: Theme.borderHairline
        border.color: Theme.border
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        z: 10
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        Text {
            id: batteryTip
            anchors.centerIn: parent
            text: I18n.tr("%1 % · %2").arg(Math.round(root.level * 100)).arg(root.stateText)
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeLabel * root.s
        }
    }
}
