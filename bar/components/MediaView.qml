pragma ComponentBehavior: Bound
import "../Singletons/Spectrum.js" as Spectrum
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root
    property color musicAccent: Theme.accent

    mTop: 24
    mLeft: 24
    mRight: 24
    mBottom: 24

    readonly property string mediaFont: Theme.fontMedia
    readonly property bool mediaMotionAllowed: visible && active && morphCloseness > 0.95
        && Flags.mediaTransitions && !Flags.reduceMotion
    onMediaMotionAllowedChanged: if (!mediaMotionAllowed) coverScale.complete()
    readonly property real coverSize: Math.min((width >= 640 * s ? 224 : 176) * s, Math.max(120 * s, height - 66 * s))

    property bool musicPresentation: false
    property string artUrl: ""
    property var artworkTransition: null
    property string serviceIcon: ""
    property string serviceLabel: ""
    property var sourceInfo: ({ glyph: "music_note", color: "" })
    property int playerCount: 0
    property bool cavaAvailable: false
    property bool cavaHasFrame: false
    property var cavaValues: []
    property var playback: ({ hasPlayer: false, isPlaying: false, albumDistinct: false, title: "", artist: "", album: "", canSeek: false, canShuffle: false, canRepeat: false, canPrevious: false, canNext: false, canToggle: false, dragging: false, dragFraction: 0, progress: 0, displayPosition: 0, remaining: 0, repeatOne: false, shuffleEnabled: false, repeatEnabled: false, length: 0, displayTime: "0:00", remainingTime: "0:00" })
    property bool lyricsSupported: false
    property bool lyricsOpen: false
    property string lyricsStatus: "idle"
    property bool lyricsSynced: false
    property var lyricLines: []
    signal lyricsRetryRequested()
    onLyricsSupportedChanged: if (!lyricsSupported) lyricsOpen = false
    Keys.onEscapePressed: event => { if (lyricsOpen) { lyricsOpen = false; event.accepted = true } else event.accepted = false }
    readonly property bool albumDistinct: playback.albumDistinct
    signal cyclePlayerRequested(int direction)
    signal previousRequested()
    signal nextRequested()
    signal togglePlayingRequested()
    signal toggleShuffleRequested()
    signal cycleRepeatRequested()
    signal seekRequested(real position)
    signal dragStarted(real fraction)
    signal dragMoved(real fraction)
    signal dragCommitted(real fraction)
    signal dragCanceled()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 360 * root.s)
        visible: !root.playback.hasPlayer
        spacing: 16 * root.s
        MediaSymbol {
            Layout.alignment: Qt.AlignHCenter
            iconName: "music_off"
            font.pixelSize: 48 * root.s
            color: Theme.iconSecondary
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Ningún medio disponible")
            font.family: root.mediaFont
            font.pixelSize: 22 * root.s
            font.weight: Font.DemiBold
            color: Theme.foreground
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Abre un reproductor para ver sus controles aquí.")
            font.family: root.mediaFont
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            color: Theme.iconSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
    ColumnLayout {
        anchors.fill: parent
        visible: root.playback.hasPlayer
        spacing: 16 * root.s
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.s
            Item {
                Layout.preferredWidth: 20 * root.s
                Layout.preferredHeight: 20 * root.s
                Image {
                    id: sourceIcon
                    anchors.fill: parent
                    source: root.serviceIcon
                    sourceSize: Qt.size(32, 32)
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }
                MediaSymbol {
                    anchors.fill: parent
                    visible: sourceIcon.status !== Image.Ready
                    iconName: "music_note"
                    font.pixelSize: 20 * root.s
                    color: Theme.iconSecondary
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.serviceLabel || (root.musicPresentation ? qsTr("Música") : qsTr("Multimedia"))
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.weight: Font.Medium
                color: Theme.iconSecondary
                elide: Text.ElideRight
            }
            Row {
                visible: root.playerCount > 1
                MediaTransportButton { iconName: "chevron_left"; accessibleName: qsTr("Reproductor anterior"); size: 32; s: root.s; onClicked: root.cyclePlayerRequested(-1) }
                MediaTransportButton { iconName: "chevron_right"; accessibleName: qsTr("Siguiente reproductor"); size: 32; s: root.s; onClicked: root.cyclePlayerRequested(1) }
            }
            Text {
                visible: root.lyricsSupported
                text: qsTr("Letras")
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                color: root.lyricsOpen ? Theme.foreground : Theme.iconSecondary
            }
            MediaTransportButton {
                objectName: "mediaLyricsToggle"
                visible: root.lyricsSupported
                iconName: "lyrics"
                accessibleName: root.lyricsOpen ? qsTr("Ocultar letras") : qsTr("Mostrar letras")
                active: root.lyricsOpen
                size: 32; iconSize: 20; s: root.s
                onClicked: root.lyricsOpen = !root.lyricsOpen
            }
        }
        RowLayout {
            objectName: "mediaIdentity"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            spacing: 28 * root.s
            ColumnLayout {
                Layout.preferredWidth: root.coverSize
                Layout.maximumWidth: root.coverSize
                Layout.alignment: Qt.AlignVCenter
                spacing: 16 * root.s
                Item {
                    id: artwork
                    objectName: "mediaArtwork"
                    Layout.preferredWidth: root.coverSize
                    Layout.preferredHeight: root.musicPresentation ? root.coverSize : root.coverSize * 9 / 16
                    scale: root.musicPresentation && Flags.mediaTransitions && !Flags.reduceMotion && !root.playback.isPlaying ? 0.94 : 1
                    Behavior on scale {
                        enabled: root.mediaMotionAllowed
                        NumberAnimation { id: coverScale; duration: Motion.emphasizedLarge; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve }
                    }
                    RadialGradient {
                        objectName: "mediaNeonField"
                        anchors.fill: parent
                        anchors.margins: -22 * root.s
                        visible: root.musicPresentation && artSource.ready
                        opacity: root.playback.isPlaying ? 1 : 0.4
                        horizontalRadius: width / 2
                        verticalRadius: height / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(root.musicAccent, 0.34) }
                            GradientStop { position: 0.70; color: Qt.alpha(root.musicAccent, 0.22) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 9 * root.s
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.alpha(root.musicAccent, 0.22)
                        border.width: root.s
                        visible: root.musicPresentation
                    }
                    Repeater {
                        objectName: "mediaRadialSpectrum"
                        model: root.musicPresentation && root.cavaAvailable && root.cavaHasFrame ? 48 : 0
                        delegate: Rectangle {
                            id: band
                            required property int index
                            readonly property real signal: root.playback.isPlaying && !Flags.reduceMotion
                                ? Math.pow(Math.max(0, Math.min(1, Spectrum.band(root.cavaValues, index, 48))), 0.72) : 0
                            readonly property real radial: artwork.width / 2 - 11 * root.s
                            objectName: "mediaRadialBand"
                            width: 3.5 * root.s
                            height: (3 + signal * 28) * root.s
                            x: (artwork.width - width) / 2
                            y: artwork.height / 2 - radial - height
                            radius: width / 2
                            color: Qt.alpha(root.musicAccent, 0.98)
                            transform: Rotation {
                                origin.x: band.width / 2
                                origin.y: band.radial + band.height
                                angle: band.index * 360 / 48
                            }
                        }
                    }
                    ArtworkImage {
                        id: artSource
                        objectName: "mediaArtworkImage"
                        anchors.fill: parent
                        source: root.artUrl
                        anchors.margins: root.musicPresentation ? 16 * root.s : 0
                        radius: root.musicPresentation ? width / 2 : 22 * root.s
                        fillMode: root.musicPresentation ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        sourceSize: Qt.size(416 * root.s, 416 * root.s)
                        transitionsEnabled: Flags.mediaTransitions
                        transitionSource: root.artworkTransition
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: !artSource.ready
                        anchors.margins: root.musicPresentation ? 16 * root.s : 0
                        radius: root.musicPresentation ? width / 2 : 22 * root.s
                        color: Theme.secondaryContainer
                        MediaSymbol {
                            anchors.centerIn: parent
                            iconName: "music_note"
                            font.pixelSize: 56 * root.s
                            color: Theme.secondaryContainerContent
                        }
                    }
                }

            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 8 * root.s
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    visible: !root.lyricsOpen
                    ColumnLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 7 * root.s
                        CrossfadeLabel {
                            objectName: "mediaTitle"
                            Layout.fillWidth: true
                            value: root.playback.title
                            animated: Flags.mediaTransitions
                            color: Theme.foreground
                            font.family: root.mediaFont
                            font.pixelSize: 28 * Flags.fontScale * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: -0.6 * root.s
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            lineHeight: 1.08
                            elide: Text.ElideRight
                        }
                        CrossfadeLabel {
                            Layout.fillWidth: true
                            value: root.playback.artist
                            animated: Flags.mediaTransitions
                            color: Theme.iconSecondary
                            font.family: root.mediaFont
                            font.pixelSize: 16 * Flags.fontScale * root.s
                            elide: Text.ElideRight
                        }
                        CrossfadeLabel {
                            Layout.fillWidth: true
                            visible: root.musicPresentation && root.playback.albumDistinct
                            value: root.playback.album
                            animated: Flags.mediaTransitions
                            color: Theme.iconSecondary
                            font.family: root.mediaFont
                            font.pixelSize: Theme.fontSizeSmall * root.s
                            elide: Text.ElideRight
                        }
                    }
                }
                LyricsView {
                    musicAccent: root.musicAccent
                    objectName: "mediaLyricsView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    visible: root.lyricsOpen && root.lyricsSupported
                    canSeek: root.playback.canSeek && !root.playback.dragging
                    motionEnabled: root.mediaMotionAllowed
                    s: root.s
                    title: root.playback.title
                    artist: root.playback.artist
                    status: root.lyricsStatus
                    synced: root.lyricsSynced
                    lines: root.lyricLines
                    position: root.playback.displayPosition
                    onSeekRequested: position => root.seekRequested(position)
                    onCloseRequested: root.lyricsOpen = false
                    onRetryRequested: root.lyricsRetryRequested()
                }
                SwiftMediaTimeline {
                    musicAccent: root.musicAccent
                    objectName: "mediaTimeline"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22 * root.s
                    visible: root.playback.canSeek
                    s: root.s
                    active: root.active && root.morphCloseness > 0.95
                    playing: root.playback.isPlaying
                    dragging: root.playback.dragging
                    progress: root.playback.progress
                    position: root.playback.displayPosition
                    length: root.playback.length
                    displayTime: root.playback.displayTime
                    onSeekRequested: position => root.seekRequested(position)
                    onDragStarted: fraction => root.dragStarted(fraction)
                    onDragMoved: fraction => root.dragMoved(fraction)
                    onDragCommitted: fraction => root.dragCommitted(fraction)
                    onDragCanceled: root.dragCanceled()
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.playback.canSeek
                    Text {
                        Layout.fillWidth: true
                        text: root.playback.displayTime
                        font.family: root.mediaFont
                        font.pixelSize: Theme.fontSizeSmall * root.s
                        color: Theme.iconSecondary
                    }
                    Text {
                        text: "−" + root.playback.remainingTime
                        font.family: root.mediaFont
                        font.pixelSize: Theme.fontSizeSmall * root.s
                        color: Theme.iconSecondary
                    }
                }
                RowLayout {
                    objectName: "mediaTransport"
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6 * root.s
                    MediaTransportButton { iconName: "shuffle"; accessibleName: qsTr("Aleatorio"); active: root.playback.shuffleEnabled; dim: !root.playback.canShuffle; s: root.s; onClicked: root.toggleShuffleRequested() }
                    MediaTransportButton { iconName: "skip_previous"; accessibleName: qsTr("Anterior"); iconSize: 30; dim: !root.playback.canPrevious; s: root.s; onClicked: root.previousRequested() }
                    MediaTransportButton {
                        objectName: "mediaToggle"
                        iconName: root.playback.isPlaying ? "pause" : "play_arrow"
                        accessibleName: root.playback.isPlaying ? qsTr("Pausar") : qsTr("Reproducir")
                        primary: true
                        primaryColor: root.musicAccent
                        playing: root.playback.isPlaying
                        motionEnabled: root.mediaMotionAllowed
                        dim: !root.playback.canToggle
                        size: 64; iconSize: 32; s: root.s
                        onClicked: root.togglePlayingRequested()
                    }
                    MediaTransportButton { iconName: "skip_next"; accessibleName: qsTr("Siguiente"); iconSize: 30; dim: !root.playback.canNext; s: root.s; onClicked: root.nextRequested() }
                    MediaTransportButton { iconName: root.playback.repeatOne ? "repeat_one" : "repeat"; accessibleName: qsTr("Repetir"); active: root.playback.repeatEnabled; dim: !root.playback.canRepeat; s: root.s; onClicked: root.cycleRepeatRequested() }
                }
            }
        }
    }
}
