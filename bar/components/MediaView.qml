pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root

    mTop: 24
    mLeft: 24
    mRight: 24
    mBottom: 24

    readonly property string mediaFont: Theme.fontMedia

    property bool musicPresentation: false
    property string artUrl: ""
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

    Item {
        anchors.fill: parent
        visible: !root.playback.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingMd * root.s
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                iconName: "music_off"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeCover * root.s
                Accessible.ignored: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Ningún medio disponible")
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeTitleLg * root.s
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 360 * root.s
                text: qsTr("Abre un reproductor para ver sus controles aquí.")
                color: Theme.iconSecondary
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8 * root.s
        visible: root.playback.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        RowLayout {
            objectName: "mediaIdentity"
            visible: !root.lyricsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24 * root.s

            Item {
                id: artworkColumn
                objectName: "mediaArtwork"
                Layout.preferredWidth: 176 * root.s
                Layout.maximumWidth: 176 * root.s
                Layout.preferredHeight: root.musicPresentation ? Layout.preferredWidth : Layout.preferredWidth * 9 / 16
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: artSource
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: root.musicPresentation ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(416 * root.s, 416 * root.s)
                    visible: false
                }
                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    color: "white"
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: artSource
                    maskSource: artMask
                    opacity: artSource.status === Image.Ready ? 1 : 0
                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
                    visible: artSource.status !== Image.Ready
                    Behavior on color { ColorAnimation { duration: Motion.standard } }
                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "music_note"
                        color: Theme.iconSecondary
                        font.pixelSize: Theme.fontSizeCover * root.s
                        Accessible.ignored: true
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    color: "transparent"
                    border.color: Theme.border
                    border.width: Theme.borderHairline * root.s
                }
            }

            ColumnLayout {
                id: content
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 10 * root.s

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm * root.s
                    Text {
                        text: root.playback.isPlaying ? (root.musicPresentation ? qsTr("Ahora suena") : qsTr("Reproduciendo")) : qsTr("En pausa")
                        color: Theme.iconSecondary
                        font.family: root.mediaFont
                        font.pixelSize: Theme.fontSizeSmall * root.s
                    }
                    Item { Layout.fillWidth: true }
                    Item {
                        Layout.preferredWidth: 16 * root.s
                        Layout.preferredHeight: 16 * root.s
                        Image {
                            id: sourceIcon
                            anchors.fill: parent
                            source: root.serviceIcon
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        MaterialIcon {
                            anchors.fill: parent
                            visible: sourceIcon.status !== Image.Ready
                            iconName: root.sourceInfo.glyph
                            color: root.sourceInfo.color || Theme.iconSecondary
                            font.pixelSize: 16 * root.s
                        }
                    }
                    Text {
                        Layout.maximumWidth: 110 * root.s
                        text: root.serviceLabel
                        color: Theme.iconSecondary
                        font.family: root.mediaFont
                        font.pixelSize: Theme.fontSizeSmall * root.s
                        elide: Text.ElideRight
                    }
                    Row {
                        visible: root.playerCount > 1
                        spacing: 0
                        CtrlBtn { iconName: "chevron_left"; accessibleName: qsTr("Reproductor anterior"); size: 28; s: root.s; onClicked: root.cyclePlayerRequested(-1) }
                        CtrlBtn { iconName: "chevron_right"; accessibleName: qsTr("Siguiente reproductor"); size: 28; s: root.s; onClicked: root.cyclePlayerRequested(1) }
                    }
                }

                AnimatedLabel {
                    objectName: "mediaTitle"
                    Layout.fillWidth: true
                    value: root.playback.title
                    color: Theme.iconPrimary
                    font.family: root.mediaFont
                    font.pixelSize: 24 * Flags.fontScale * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.5 * root.s
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    lineHeight: 1.12
                    elide: Text.ElideRight
                }
                AnimatedLabel {
                    Layout.fillWidth: true
                    value: root.playback.artist
                    color: Theme.iconSecondary
                    font.family: root.mediaFont
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    font.letterSpacing: 0.05 * root.s
                    elide: Text.ElideRight
                }
                AnimatedLabel {
                    Layout.fillWidth: true
                    visible: root.musicPresentation && root.playback.albumDistinct
                    value: root.playback.album
                    color: Theme.iconSecondary
                    font.family: root.mediaFont
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    elide: Text.ElideRight
                }
                Item {
                    id: cavaView
                    visible: root.musicPresentation && root.cavaAvailable && root.cavaHasFrame
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20 * root.s
                    readonly property int count: Math.max(12, Math.min(32, Math.floor(width / (8 * root.s))))
                    readonly property real gap: 3 * root.s
                    readonly property real barWidth: Math.max(2 * root.s, (width - (count - 1) * gap) / count)
                    Repeater {
                        model: cavaView.count
                        delegate: Rectangle {
                            required property int index
                            readonly property real signal: root.playback.isPlaying && root.cavaAvailable && root.cavaValues.length > 0
                                ? root.cavaValues[Math.min(root.cavaValues.length - 1,
                                  Math.floor(index * root.cavaValues.length / cavaView.count))] || 0 : 0
                            width: cavaView.barWidth
                            height: Math.max(2 * root.s, (2 * root.s) + signal * 14 * root.s)
                            x: index * (cavaView.barWidth + cavaView.gap)
                            y: cavaView.height - height
                            radius: width / 2
                            color: Qt.alpha(Theme.foreground, 0.20 + signal * 0.35)
                            Behavior on height { Anim { type: Anim.FastEffects } }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                    }
                }

            }
        }

        LyricsView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            visible: root.lyricsOpen && root.lyricsSupported
            s: root.s
            title: root.playback.title
            artist: root.playback.artist
            status: root.lyricsStatus
            synced: root.lyricsSynced
            lines: root.lyricLines
            position: root.playback.displayPosition
            onCloseRequested: root.lyricsOpen = false
            onRetryRequested: root.lyricsRetryRequested()
        }
        MediaTimeline {
            objectName: "mediaTimeline"
            Layout.fillWidth: true
            Layout.preferredHeight: 28 * root.s
            visible: root.playback.canSeek
            enabled: root.playback.canSeek
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
                text: root.playback.displayTime
                color: Theme.iconSecondary
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.letterSpacing: 0.2 * root.s
                Layout.fillWidth: true
            }
            Text {
                text: "−" + root.playback.remainingTime
                color: Theme.iconSecondary
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.letterSpacing: 0.2 * root.s
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            objectName: "mediaTransport"
            Layout.fillWidth: true
            spacing: Theme.spacingLg * root.s
            CtrlBtn {
                objectName: "mediaLyricsToggle"
                visible: root.lyricsSupported
                iconName: "lyrics"
                accessibleName: root.lyricsOpen ? qsTr("Ocultar letras") : qsTr("Mostrar letras")
                active: root.lyricsOpen
                size: 36; s: root.s
                onClicked: root.lyricsOpen = !root.lyricsOpen
            }
            CtrlBtn { visible: root.musicPresentation || root.playback.canShuffle; iconName: "shuffle"; accessibleName: qsTr("Aleatorio"); active: root.playback.shuffleEnabled; dim: !root.playback.canShuffle; s: root.s; onClicked: root.toggleShuffleRequested() }
            Item { Layout.fillWidth: true }
            CtrlBtn { iconName: "skip_previous"; iconSize: 28; accessibleName: qsTr("Anterior"); dim: !root.playback.canPrevious; s: root.s; onClicked: root.previousRequested() }
            CtrlBtn {
                objectName: "mediaToggle"
                iconName: root.playback.isPlaying ? "pause" : "play_arrow"
                accessibleName: root.playback.isPlaying ? qsTr("Pausar") : qsTr("Reproducir")
                size: 52
                iconSize: 30
                primary: true
                dim: !root.playback.canToggle
                s: root.s
                onClicked: root.togglePlayingRequested()
            }
            CtrlBtn { iconName: "skip_next"; iconSize: 28; accessibleName: qsTr("Siguiente"); dim: !root.playback.canNext; s: root.s; onClicked: root.nextRequested() }
            Item { Layout.fillWidth: true }
            CtrlBtn { visible: root.musicPresentation || root.playback.canRepeat; iconName: root.playback.repeatOne ? "repeat_one" : "repeat"; accessibleName: qsTr("Repetir"); active: root.playback.repeatEnabled; dim: !root.playback.canRepeat; s: root.s; onClicked: root.cycleRepeatRequested() }
        }
    }
}
