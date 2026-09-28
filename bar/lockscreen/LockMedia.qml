import QtQuick
import "../components"
import "../Singletons"

Item {
    id: root
    required property Item wallpaperItem
    property real sampleX: 0
    property real sampleY: 0
    property real unit: 1
    property var player: null
    property string artUrl: ""
    property string trackKey: ""
    readonly property bool hasPlayer: session.hasPlayer
    implicitHeight: 142 * unit
    MediaSession { id: session; player: root.player; trackKey: root.trackKey; active: root.visible }
    LockGlass { anchors.fill: parent; radius: 26 * root.unit; wallpaperItem: root.wallpaperItem; sampleX: root.sampleX; sampleY: root.sampleY }
    IslandMediaCover {
        x: 20 * root.unit; y: 18 * root.unit
        diameter: 52 * root.unit
        artUrl: root.artUrl
    }
    Column {
        x: 82 * root.unit; y: 20 * root.unit
        width: parent.width - x - 22 * root.unit
        spacing: 4 * root.unit
        Text {
            width: parent.width; text: session.title; elide: Text.ElideRight
            color: "#f8f8fa"; font.family: Theme.fontMedia
            font.pixelSize: 14 * root.unit * Flags.fontScale; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; text: session.artist; elide: Text.ElideRight
            color: "#bbffffff"; font.family: Theme.fontMedia; font.pixelSize: 12 * root.unit * Flags.fontScale
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 82 * root.unit
        spacing: 20 * root.unit
        LockButton { unit: root.unit; flatStyle: true; iconName: "skip_previous"; text: qsTr("Anterior"); enabled: session.canPrevious; onClicked: session.previous() }
        LockButton { unit: root.unit; iconName: session.isPlaying ? "pause" : "play_arrow"; text: session.isPlaying ? qsTr("Pausar") : qsTr("Reproducir"); enabled: session.canToggle; onClicked: session.togglePlaying() }
        LockButton { unit: root.unit; flatStyle: true; iconName: "skip_next"; text: qsTr("Siguiente"); enabled: session.canNext; onClicked: session.next() }
    }
}
