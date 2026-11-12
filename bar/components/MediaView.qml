pragma ComponentBehavior: Bound
import "../Singletons/Spectrum.js" as Spectrum
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    // A new song lands like a drop: the cover dips, one wave crosses the ripples
    // and the new cover and metadata rise from below, one after another.
    readonly property string trackKey: JSON.stringify([playback.title, playback.artist])
    property bool trackKeyReady: false
    property real trackDip: 0
    property real trackWaveT: 1
    Component.onCompleted: trackKeyReady = true
    onTrackKeyChanged: {
        if (!trackKeyReady || !musicPresentation || !mediaMotionAllowed || !playback.title) return
        trackLanding.restart()
    }
    onMediaMotionAllowedChanged: if (!mediaMotionAllowed) { coverScale.complete(); trackLanding.stop(); trackDip = 0; trackWaveT = 1 }
    ParallelAnimation {
        id: trackLanding
        SequentialAnimation {
            NumberAnimation { target: root; property: "trackDip"; to: 1; duration: Motion.standardSmall; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "trackDip"; to: 0; duration: Motion.emphasizedLarge; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve }
        }
        NumberAnimation { target: root; property: "trackWaveT"; from: 0; to: 1; duration: Motion.emphasizedLarge * 1.5; easing.type: Easing.OutCubic }
    }
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
            text: I18n.tr("Ningún medio disponible")
            font.family: root.mediaFont
            font.pixelSize: 20 * root.s
            font.weight: Font.DemiBold
            color: Theme.foreground
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: I18n.tr("Abre un reproductor para ver sus controles aquí.")
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
                text: root.serviceLabel || (root.musicPresentation ? I18n.tr("Música") : I18n.tr("Multimedia"))
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.weight: Font.Medium
                color: Theme.iconSecondary
                elide: Text.ElideRight
            }
            Row {
                visible: root.playerCount > 1
                MediaTransportButton { iconName: "chevron_left"; accessibleName: I18n.tr("Reproductor anterior"); size: 32; s: root.s; onClicked: root.cyclePlayerRequested(-1) }
                MediaTransportButton { iconName: "chevron_right"; accessibleName: I18n.tr("Siguiente reproductor"); size: 32; s: root.s; onClicked: root.cyclePlayerRequested(1) }
            }
            Text {
                visible: root.lyricsSupported
                text: I18n.tr("Letras")
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                color: root.lyricsOpen ? Theme.foreground : Theme.iconSecondary
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            }
            MediaTransportButton {
                objectName: "mediaLyricsToggle"
                visible: root.lyricsSupported
                iconName: "lyrics"
                accessibleName: root.lyricsOpen ? I18n.tr("Ocultar letras") : I18n.tr("Mostrar letras")
                active: root.lyricsOpen
                size: 32; iconSize: 20; s: root.s
                onClicked: root.lyricsOpen = !root.lyricsOpen
            }
        }
        RowLayout {
            id: mediaIdentity
            objectName: "mediaIdentity"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            spacing: 28 * root.s
            ColumnLayout {
                id: artworkColumn
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
                    transform: Scale {
                        origin.x: artwork.width / 2; origin.y: artwork.height / 2
                        xScale: 1 - 0.04 * root.trackDip; yScale: xScale
                    }
                    Behavior on scale {
                        enabled: root.mediaMotionAllowed
                        NumberAnimation { id: coverScale; duration: Motion.emphasizedLarge; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve }
                    }
                    // Agua: la música mueve el agua alrededor de la portada; nada emite luz.
                    // Tres ondas (graves, medios, agudos) se alejan con su banda y vuelven en silencio.
                    Repeater {
                        objectName: "mediaRipples"
                        model: root.musicPresentation && artSource.ready ? 3 : 0
                        delegate: Rectangle {
                            id: ripple
                            required property int index
                            readonly property real signal: root.playback.isPlaying && !Flags.reduceMotion
                                && root.cavaAvailable && root.cavaHasFrame
                                ? Math.pow(Math.max(0, Math.min(1, Spectrum.band(root.cavaValues, index, 3))), 0.8) : 0
                            readonly property real excursion: signal * (5 + index * 3) * root.s
                            readonly property real radius0: artSource.width / 2 + (5 + index * 6) * root.s
                            objectName: "mediaRipple"
                            width: 2 * (radius0 + excursion)
                            height: width
                            x: (artwork.width - width) / 2
                            y: (artwork.height - height) / 2
                            radius: width / 2
                            color: "transparent"
                            antialiasing: true
                            border.width: Math.max(1, 1.4 * root.s)
                            border.color: Qt.alpha(root.musicAccent,
                                (0.42 - index * 0.12) * (root.playback.isPlaying ? 0.55 + 0.45 * signal : 0.45))
                        }
                    }
                    Rectangle {
                        objectName: "mediaTrackWave"
                        readonly property real r0: artSource.width / 2
                        width: 2 * (r0 + 34 * root.s * root.trackWaveT)
                        height: width
                        x: (artwork.width - width) / 2
                        y: (artwork.height - height) / 2
                        radius: width / 2
                        color: "transparent"
                        antialiasing: true
                        border.width: Math.max(1, (2.2 - 1.2 * root.trackWaveT) * root.s)
                        border.color: root.musicAccent
                        opacity: 0.65 * Math.pow(1 - root.trackWaveT, 1.5)
                        visible: root.musicPresentation && root.trackWaveT < 1
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
                        swapTravel: root.musicPresentation && root.mediaMotionAllowed ? 12 * root.s : 0
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
                    // Misma luz que la gota: hondura abajo, menisco fino y reflejo del sol arriba.
                    Item {
                        anchors.fill: artSource
                        visible: root.musicPresentation && artSource.ready
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            antialiasing: true
                            gradient: Gradient {
                                GradientStop { position: 0.5; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.22) }
                            }
                            border.color: Qt.alpha(Theme.foreground, 0.14)
                            border.width: Theme.borderHairline
                        }
                        Shape {
                            objectName: "mediaArtworkGlint"
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.5)
                                strokeWidth: 2 * root.s
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: artSource.width / 2; centerY: artSource.height / 2
                                    radiusX: artSource.width / 2 - 7 * root.s
                                    radiusY: artSource.height / 2 - 7 * root.s
                                    startAngle: -152; sweepAngle: 44; moveToStart: true
                                }
                            }
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
                    id: infoArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    opacity: root.lyricsOpen ? 0 : 1
                    visible: opacity > 0.01
                    enabled: !root.lyricsOpen
                    Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    transform: Translate {
                        y: Flags.reduceMotion ? 0 : (root.lyricsOpen ? -6 : 0) * root.s
                        Behavior on y { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    }
                    ColumnLayout {
                        id: infoColumn
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 7 * root.s
                        CrossfadeLabel {
                            objectName: "mediaTitle"
                            Layout.fillWidth: true
                            value: root.playback.title
                            animated: Flags.mediaTransitions
                            sequential: true
                            swapTravel: root.mediaMotionAllowed ? 10 * root.s : 0
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
                            sequential: true
                            swapTravel: root.mediaMotionAllowed ? 8 * root.s : 0
                            delay: root.mediaMotionAllowed ? 60 : 0
                            color: Theme.iconSecondary
                            font.family: root.mediaFont
                            font.pixelSize: 15 * Flags.fontScale * root.s
                            elide: Text.ElideRight
                        }
                        CrossfadeLabel {
                            Layout.fillWidth: true
                            visible: root.musicPresentation && root.playback.albumDistinct
                            value: root.playback.album
                            animated: Flags.mediaTransitions
                            sequential: true
                            swapTravel: root.mediaMotionAllowed ? 6 * root.s : 0
                            delay: root.mediaMotionAllowed ? 110 : 0
                            color: Theme.iconSecondary
                            font.family: root.mediaFont
                            font.pixelSize: Theme.fontSizeSmall * root.s
                            elide: Text.ElideRight
                        }
                    }
                }
                LyricsView {
                    id: lyricsView
                    musicAccent: root.musicAccent
                    objectName: "mediaLyricsView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    readonly property bool shown: root.lyricsOpen && root.lyricsSupported
                    open: shown
                    opacity: shown ? 1 : 0
                    visible: opacity > 0.01
                    enabled: shown
                    Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    transform: Translate {
                        y: Flags.reduceMotion ? 0 : (parent.shown ? 0 : 6) * root.s
                        Behavior on y { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    }
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
                    id: timeline
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
                    MediaTransportButton { iconName: "shuffle"; accessibleName: I18n.tr("Aleatorio"); active: root.playback.shuffleEnabled; dim: !root.playback.canShuffle; s: root.s; onClicked: root.toggleShuffleRequested() }
                    MediaTransportButton { iconName: "skip_previous"; accessibleName: I18n.tr("Anterior"); iconSize: 30; dim: !root.playback.canPrevious; s: root.s; onClicked: root.previousRequested() }
                    MediaTransportButton {
                        objectName: "mediaToggle"
                        iconName: root.playback.isPlaying ? "pause" : "play_arrow"
                        accessibleName: root.playback.isPlaying ? I18n.tr("Pausar") : I18n.tr("Reproducir")
                        primary: true
                        primaryColor: root.musicAccent
                        playing: root.playback.isPlaying
                        motionEnabled: root.mediaMotionAllowed
                        dim: !root.playback.canToggle
                        size: 64; iconSize: 32; s: root.s
                        onClicked: root.togglePlayingRequested()
                    }
                    MediaTransportButton { iconName: "skip_next"; accessibleName: I18n.tr("Siguiente"); iconSize: 30; dim: !root.playback.canNext; s: root.s; onClicked: root.nextRequested() }
                    MediaTransportButton { iconName: root.playback.repeatOne ? "repeat_one" : "repeat"; accessibleName: I18n.tr("Repetir"); active: root.playback.repeatEnabled; dim: !root.playback.canRepeat; s: root.s; onClicked: root.cycleRepeatRequested() }
                }
            }
        }
    }
}
