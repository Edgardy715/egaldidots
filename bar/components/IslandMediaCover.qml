import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"
import "../Singletons"

/** Circular cover art and playback-progress ring for the compact media chip. */
Item {
    id: root
    property color musicAccent: Theme.accent

    property real s: 1
    property real diameter: 34
    property real ringWidth: 2
    property real ringGap: 2
    property real progress: 0
    property bool hasProgress: false
    property bool hovered: false
    property bool pressed: false
    property string artUrl: ""
    property string trackKey: ""
    property bool trackTransitions: false
    readonly property bool trackMotionAllowed: trackTransitions && visible
        && Flags.mediaTransitions && !Flags.reduceMotion
    property real trackCompression: 0
    property bool trackInitialized: false
    onTrackKeyChanged: {
        if (!trackInitialized || !trackKey || !trackMotionAllowed) return
        trackResponse.to = 1
        trackResponse.restart()
        releaseTrack.restart()
    }
    onTrackMotionAllowedChanged: if (!trackMotionAllowed) {
        releaseTrack.stop()
        trackResponse.stop()
        trackCompression = 0
    }
    Component.onCompleted: trackInitialized = true
    SmoothedAnimation {
        id: trackResponse
        target: root
        property: "trackCompression"
        to: 0
        duration: Motion.standardSmall
        velocity: -1
    }
    Timer {
        id: releaseTrack
        interval: Motion.press
        onTriggered: {
            trackResponse.to = 0
            trackResponse.restart()
        }
    }

    width: diameter
    height: diameter

    InteractionMotion { id: response; hovered: root.hovered; pressed: root.pressed; extent: root.diameter }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: height / 2
        color: "transparent"
        border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
        border.width: root.ringWidth
        visible: root.hasProgress
    }
    Shape {
        id: progressRing
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        preferredRendererType: Shape.CurveRenderer
        visible: root.hasProgress
        layer.enabled: visible && root.progress > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(root.musicAccent, 0.65 + response.presence * 0.25)
            shadowBlur: 0.65
            blurMax: 12
        }
        ShapePath {
            strokeColor: root.musicAccent
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.ringWidth / 2
                radiusY: root.height / 2 - root.ringWidth / 2
                startAngle: -90
                sweepAngle: 360 * root.progress
                moveToStart: true
            }
        }
    }

    Item {
        id: cover
        anchors.centerIn: parent
        width: root.diameter - 2 * (root.ringWidth + root.ringGap)
        height: width
        scale: response.visualScale * (1 - 0.07 * root.trackCompression)

        ArtworkImage {
            id: artwork
            anchors.fill: parent
            radius: height / 2
            source: root.artUrl
            sourceSize: Qt.size(cover.width * 2, cover.height * 2)
            transitionsEnabled: Flags.mediaTransitions
            swapTravel: root.trackTransitions ? 4 * root.s : 0
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconName: "music_note"
            color: Theme.iconSecondary
            font.pixelSize: cover.width * 0.58
            visible: !artwork.ready
            Accessible.ignored: true
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.color: Theme.border
            border.width: Theme.borderHairline
            antialiasing: true
        }
    }
}
