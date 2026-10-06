import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real volume: 0
    property bool muted: true
    signal activated()

    width: 19 * s
    height: 26 * s

    MaterialIcon {
        anchors.centerIn: parent
        iconName: Icons.getVolumeIcon(root.volume, root.muted)
        color: Theme.iconSecondary
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        interaction: volumeHit.motion
    }
    MotionArea {
        id: volumeHit
        anchors.fill: parent
        feedbackEnabled: false
        accessibleName: qsTr("Abrir mezclador de volumen")
        onClicked: root.activated()
    }
}
