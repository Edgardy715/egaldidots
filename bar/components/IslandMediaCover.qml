import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"
import "../Singletons"

/** Circular cover art, lit like a stone under water, with an optional playback-progress ring. */
Item {
    id: root
    property color musicAccent: Theme.accent

    property real s: 1
    property real diameter: 34
    // Ring of the plain pill; the water drop shows the cover alone.
    property real ringWidth: 2
    property real ringGap: 2
    property real progress: 0
    property bool hasProgress: false
    // Water drop: the ring is a quiet waterline (no glow) and a new song lands as a wave.
    property bool ringGlow: true
    property color ringTrackColor: Qt.alpha(Theme.foreground, Theme.alphaSoft)
    property color ringColor: musicAccent
    property bool trackWave: false
    // Seeks and the reset to a new song drain or fill the arc instead of jumping.
    property real shownProgress: progress
    Behavior on shownProgress {
        enabled: root.visible && !Flags.reduceMotion
        NumberAnimation { duration: Motion.standardLarge; easing.type: Motion.easeStandard }
    }
    property real waveT: 1
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
        if (trackWave) wave.restart()
    }
    onTrackMotionAllowedChanged: if (!trackMotionAllowed) {
        releaseTrack.stop()
        trackResponse.stop()
        trackCompression = 0
        wave.stop()
        waveT = 1
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
    NumberAnimation {
        id: wave
        target: root; property: "waveT"; from: 0; to: 1
        duration: Motion.emphasizedLarge * 1.3
        easing.type: Easing.OutCubic
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
        border.color: root.ringTrackColor
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
        layer.enabled: root.ringGlow && visible && root.shownProgress > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(root.musicAccent, 0.65 + response.presence * 0.25)
            shadowBlur: 0.65
            blurMax: 12
        }
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.ringWidth / 2
                radiusY: root.height / 2 - root.ringWidth / 2
                startAngle: -90
                sweepAngle: 360 * root.shownProgress
                moveToStart: true
            }
        }
    }

    // The song lands like a drop: one wave leaves the cover edge and dies at the glass.
    Rectangle {
        objectName: "mediaCoverWave"
        readonly property real r0: cover.width / 2
        readonly property real r1: root.diameter / 2 + 2 * root.s
        anchors.centerIn: parent
        width: 2 * (r0 + (r1 - r0) * root.waveT)
        height: width
        radius: width / 2
        color: "transparent"
        antialiasing: true
        border.width: Math.max(1, 1.6 * root.s)
        border.color: root.musicAccent
        opacity: 0.7 * Math.pow(1 - root.waveT, 1.4)
        visible: root.waveT < 1
    }

    // Agua: la portada no emite luz; está sumergida en la gota y la ilumina el sol de arriba.
    Item {
        id: cover
        anchors.centerIn: parent
        width: root.hasProgress ? root.diameter - 2 * (root.ringWidth + root.ringGap) : root.diameter
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
        // Profundidad: el agua oscurece la mitad inferior, lejos del sol.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.28) }
            }
        }
        // Menisco: borde fino donde el agua toca la portada.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.color: Qt.alpha(Theme.foreground, 0.16)
            border.width: Theme.borderHairline
            antialiasing: true
        }
        // Reflejo especular del sol en la superficie curva.
        Shape {
            objectName: "mediaCoverGlint"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.75 + 0.25 * response.presence
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.7)
                strokeWidth: 1.6 * root.s
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: cover.width / 2; centerY: cover.height / 2
                    radiusX: cover.width / 2 - 2.2 * root.s
                    radiusY: cover.height / 2 - 2.2 * root.s
                    startAngle: -150; sweepAngle: 48; moveToStart: true
                }
            }
        }
    }
}
