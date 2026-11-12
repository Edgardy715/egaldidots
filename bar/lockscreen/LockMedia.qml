import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell.Widgets
import "../components"
import "../Singletons"

// Marea media capsule: one floating strip for rest and access. A round cover
// that turns like a disc while playing, the track on one line, a hairline
// timeline and the transport on the right.
Item {
    id: root
    property real unit: 1
    property var player: null
    property string artUrl: ""
    property string trackKey: ""
    readonly property bool hasPlayer: session.hasPlayer
    readonly property real fontScale: Math.max(1, Flags.fontScale * 0.85)
    implicitHeight: Math.round(64 * unit * fontScale)
    MediaSession { id: session; player: root.player; positionOffset: Players.offsetFor(player); trackKey: root.trackKey; active: root.visible }
    LockGlass { anchors.fill: parent; radius: height / 2; unit: root.unit }
    // A new track slides its text in from the cover side.
    property real swap: 1
    onTrackKeyChanged: if (!Flags.reduceMotion && visible) swapAnim.restart()
    NumberAnimation { id: swapAnim; target: root; property: "swap"; from: 0; to: 1; duration: Motion.standardLarge; easing.type: Motion.easeStandard }
    ClippingRectangle {
        id: cover
        objectName: "lockMediaCover"
        x: Math.round(8 * root.unit); anchors.verticalCenter: parent.verticalCenter
        width: root.height - 16 * root.unit; height: width
        radius: width / 2
        color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
        // Turning the clipped cover as a whole keeps its clip texture static.
        NumberAnimation on rotation {
            from: 0; to: 360
            duration: 24000
            loops: Animation.Infinite
            running: root.visible && !Flags.reduceMotion && artwork.status === Image.Ready
            paused: running && !session.isPlaying
        }
        Image {
            id: artwork
            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(cover.width * 2, cover.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        MaterialIcon {
            anchors.centerIn: parent
            visible: artwork.status !== Image.Ready
            iconName: "music_note"
            font.pixelSize: cover.width * 0.42
            color: Theme.iconSecondary
            Accessible.ignored: true
        }
    }
    Column {
        id: metadata
        objectName: "lockMediaMetadata"
        x: cover.x + cover.width + 12 * root.unit
        anchors.verticalCenter: parent.verticalCenter
        width: controls.x - x - 10 * root.unit
        spacing: 2 * root.unit
        opacity: root.swap
        transform: Translate { x: -10 * root.unit * (1 - root.swap) }
        Text {
            objectName: "lockMediaTitle"
            width: parent.width; text: session.title
            elide: Text.ElideRight
            color: Theme.foreground; font.family: Theme.fontMedia
            font.pixelSize: 13 * root.unit * Flags.fontScale; font.weight: Font.Medium
        }
        Text {
            width: parent.width; text: session.artist; elide: Text.ElideRight
            visible: text.length > 0
            color: Theme.iconSecondary; font.family: Theme.fontMedia
            font.pixelSize: 11 * root.unit * Flags.fontScale
        }
        Controls.Slider {
            id: seek
            objectName: "lockMediaSeek"
            width: parent.width
            height: 12 * root.unit
            padding: 0
            visible: session.canSeek
            from: 0; to: 1
            value: session.progress
            enabled: session.canSeek
            Accessible.name: I18n.tr("Posición de reproducción")
            onPressedChanged: {
                if (pressed) session.beginDrag(value)
                else session.commitDrag(value)
            }
            onMoved: {
                if (pressed) session.dragFraction = value
                else if (root.player) session.seekTo(value * root.player.length)
            }
            background: Rectangle {
                y: (seek.height - height) / 2
                width: seek.availableWidth
                height: (seek.hovered || seek.pressed ? 4 : 2) * root.unit
                radius: height / 2; color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                Behavior on height { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; easing.type: Motion.easeStandard } }
                Rectangle { width: parent.width * seek.visualPosition; height: parent.height; radius: parent.radius; color: Theme.foreground }
            }
            handle: Rectangle {
                x: seek.visualPosition * (seek.availableWidth - width)
                y: (seek.height - height) / 2
                width: 10 * root.unit; height: width; radius: width / 2
                color: Theme.foreground
                scale: seek.hovered || seek.pressed || seek.activeFocus ? 1 : 0
                Behavior on scale { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast; easing.type: Easing.OutBack } }
            }
        }
    }
    Row {
        id: controls
        objectName: "lockMediaControls"
        x: parent.width - width - 10 * root.unit
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * root.unit
        LockButton { anchors.verticalCenter: parent.verticalCenter; unit: root.unit; width: 36 * root.unit; height: width; iconSize: 20 * root.unit; flatStyle: true; iconName: "skip_previous"; text: I18n.tr("Anterior"); enabled: session.canPrevious; onClicked: session.previous() }
        LockButton { anchors.verticalCenter: parent.verticalCenter; unit: root.unit; width: 42 * root.unit; height: width; iconSize: 22 * root.unit; solid: true; iconName: session.isPlaying ? "pause" : "play_arrow"; text: session.isPlaying ? I18n.tr("Pausar") : I18n.tr("Reproducir"); enabled: session.canToggle; onClicked: session.togglePlaying() }
        LockButton { anchors.verticalCenter: parent.verticalCenter; unit: root.unit; width: 36 * root.unit; height: width; iconSize: 20 * root.unit; flatStyle: true; iconName: "skip_next"; text: I18n.tr("Siguiente"); enabled: session.canNext; onClicked: session.next() }
    }
}
