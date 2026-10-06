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
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24 * root.s
        visible: root.playback.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        Item {
            id: artworkColumn
            Layout.preferredWidth: Math.min(208 * root.s, parent.height)
            Layout.preferredHeight: root.musicPresentation ? Layout.preferredWidth : Layout.preferredWidth * 9 / 16
            Layout.alignment: Qt.AlignVCenter

            RectangularGlow {
                objectName: "albumHalo"
                anchors.fill: parent
                anchors.margins: -2 * root.s
                glowRadius: 8 * root.s
                spread: 0.1
                cornerRadius: Theme.radiusXxl * root.s + 2 * root.s
                color: Theme.accent
                visible: root.open && root.visible && root.musicPresentation
                    && artSource.status === Image.Ready
                readonly property real energy: {
                    if (!visible) return 0
                    const values = root.cavaValues
                    return ((values[4] || 0) + (values[11] || 0) + (values[18] || 0)) / 3
                }
                opacity: root.playback.isPlaying && !Flags.reduceMotion && root.cavaAvailable && root.cavaHasFrame
                    ? 0.20 + energy * 0.25 : 0.16
            }
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
                radius: Theme.radiusXxl * root.s
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
                radius: Theme.radiusXxl * root.s
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
                radius: Theme.radiusXxl * root.s
                color: "transparent"
                border.color: Theme.border
                border.width: Theme.borderHairline * root.s
            }
        }

        ColumnLayout {
            id: content
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6 * root.s

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm * root.s
                Text {
                    text: root.playback.isPlaying ? (root.musicPresentation ? qsTr("Ahora suena") : qsTr("Reproduciendo")) : qsTr("En pausa")
                    color: Qt.alpha(Theme.foreground, 0.65)
                    font.family: root.mediaFont
                    font.pixelSize: 11 * root.s
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
                Layout.fillWidth: true
                value: root.playback.title
                color: Theme.iconPrimary
                font.family: root.mediaFont
                font.pixelSize: 20 * Flags.fontScale * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: -0.35 * root.s
                wrapMode: Text.Wrap
                maximumLineCount: 2
                lineHeight: 1.12
                elide: Text.ElideRight
            }
            AnimatedLabel {
                Layout.fillWidth: true
                value: root.playback.artist + (root.musicPresentation && root.playback.albumDistinct ? " · " + root.playback.album : "")
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.letterSpacing: 0.05 * root.s
                elide: Text.ElideRight
            }
            Item {
                id: cavaView
                visible: root.musicPresentation
                Layout.fillWidth: true
                Layout.preferredHeight: 18 * root.s
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

            Item {
                id: seekBar
                Layout.fillWidth: true
                Layout.preferredHeight: 24 * root.s
                visible: root.playback.canSeek
                readonly property real trackInset: 2 * root.s
                readonly property real trackWidth: width - 4 * root.s
                function fractionAt(x) { return Math.max(0, Math.min(1, (x - trackInset) / trackWidth)) }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: seekMouse.activeFocus ? Theme.borderHairline : 0
                    border.color: Theme.accent
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: seekBar.trackInset
                    width: seekBar.trackWidth
                    height: 4 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                    Rectangle {
                        width: parent.width * root.playback.progress
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(Theme.foreground, 0.85)
                        Behavior on width { enabled: !root.playback.dragging; Anim { type: Anim.FastEffects } }
                    }
                }
                Rectangle {
                    x: seekBar.trackInset + seekBar.trackWidth * root.playback.progress - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.foreground
                    opacity: seekMouse.containsMouse || root.playback.dragging ? 1 : 0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    scale: Flags.reduceMotion ? 1 : seekMouse.containsMouse || root.playback.dragging ? Motion.gripScale : 1
                    Behavior on scale { Anim { type: Anim.FastEffects } }
                }
                MouseArea {
                    id: seekMouse
                    objectName: "mediaSeek"
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.playback.canSeek
                    activeFocusOnTab: root.playback.canSeek
                    Accessible.role: Accessible.Slider
                    Accessible.name: qsTr("Posición de reproducción")
                    Accessible.description: root.playback.displayTime
                    Accessible.onIncreaseAction: root.seekRequested(root.playback.displayPosition + 5)
                    Accessible.onDecreaseAction: root.seekRequested(root.playback.displayPosition - 5)
                    Keys.onLeftPressed: root.seekRequested(root.playback.displayPosition - 5)
                    Keys.onRightPressed: root.seekRequested(root.playback.displayPosition + 5)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Home) root.seekRequested(0)
                        else if (event.key === Qt.Key_End) root.seekRequested(root.playback.length)
                        else return
                        event.accepted = true
                    }
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => { root.dragStarted(seekBar.fractionAt(mouse.x)) }
                    onPositionChanged: (mouse) => { if (root.playback.dragging) root.dragMoved(seekBar.fractionAt(mouse.x)) }
                    onReleased: (mouse) => { root.dragCommitted(seekBar.fractionAt(mouse.x)) }
                    onCanceled: root.dragCanceled()
                }
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
                Layout.fillWidth: true
                spacing: Theme.spacingLg * root.s
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
}
