import QtQuick
import "../Singletons"

// Presentation only; the bar adapter owns player selection and actions.
Item {
    id: root
    property color musicAccent: Theme.accent
    property real s: 1
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property bool playing: false
    property bool hasFrame: false
    property var values: []
    readonly property bool showVisualizer: width >= 130 * s
    signal requestMedia()
    height: 38 * s

    IslandMediaSummary {
        musicAccent: root.musicAccent
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        s: root.s
        coverDiameter: 36 * root.s
        spacing: 12 * root.s
        textWidth: {
            const remaining = root.width - 48 * root.s - (visualizer.visible ? 34 * root.s : 0)
            return remaining >= 64 * root.s ? remaining : 0
        }
        artUrl: root.artUrl
        hasProgress: false
        title: root.title
        artist: root.artist
        titlePixelSize: 13 * root.s
        artistPixelSize: 11 * root.s
        showArtist: textWidth >= 50 * root.s && root.artist.length > 0
    }
    MotionArea {
        id: openHit
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        feedbackEnabled: false
        accessibleName: qsTr("Abrir música: %1 · %2").arg(root.title).arg(root.artist)
        onClicked: root.requestMedia()
    }
    IslandMediaVisualizer {
        musicAccent: root.musicAccent
        id: visualizer
        x: root.width - width
        anchors.verticalCenter: parent.verticalCenter
        s: root.s
        coreH: root.height
        hasMedia: root.showVisualizer
        hiddenForAuth: !root.playing
        isPlaying: root.playing
        hasFrame: root.hasFrame
        values: root.values
        onRequestMedia: root.requestMedia()
    }
}
