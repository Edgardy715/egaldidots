import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell.Widgets
import "../components"
import "../Singletons"

Item {
    id: root
    property real unit: 1
    property var player: null
    property string artUrl: ""
    property string trackKey: ""
    property bool embedded: false
    readonly property bool landscape: !embedded && width >= 480 * unit
    readonly property bool showTimeline: !embedded && session.canSeek
    readonly property bool hasPlayer: session.hasPlayer
    implicitHeight: Math.max(cover.y + cover.height, controls.y + controls.height)
    MediaSession { id: session; player: root.player; trackKey: root.trackKey; active: root.visible && !root.embedded }
    ClippingRectangle {
        id: cover
        objectName: "lockMediaCover"
        x: root.landscape ? 0 : (parent.width - width) / 2
        y: 0
        width: Math.min(parent.width - 48 * root.unit, (root.embedded ? 80 : root.landscape ? 160 : 112) * root.unit); height: width
        radius: 16 * root.unit
        color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
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
            font.pixelSize: cover.width * 0.38
            color: Theme.iconSecondary
            Accessible.ignored: true
        }
    }
    Column {
        id: metadata
        objectName: "lockMediaMetadata"
        x: root.landscape ? cover.width + 24 * root.unit : 0
        y: root.landscape ? 8 * root.unit : cover.height + 16 * root.unit
        width: parent.width - x
        spacing: 5 * root.unit
        Text {
            objectName: "lockMediaTitle"
            width: parent.width; text: session.title
            maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight
            horizontalAlignment: root.landscape ? Text.AlignLeft : Text.AlignHCenter
            color: Theme.foreground; font.family: Theme.font
            font.pixelSize: (root.embedded ? 15 : 24) * root.unit * Flags.fontScale; font.weight: Font.Medium
        }
        Text {
            width: parent.width; text: session.artist; elide: Text.ElideRight
            horizontalAlignment: root.landscape ? Text.AlignLeft : Text.AlignHCenter
            color: Qt.alpha(Theme.foreground, 0.9); font.family: Theme.font
            font.pixelSize: (root.embedded ? 13 : 16) * root.unit * Flags.fontScale
        }
    }
    Column {
        id: timeline
        x: metadata.x
        y: metadata.y + metadata.height + 16 * root.unit
        width: metadata.width
        visible: root.showTimeline
        spacing: 0
        Controls.Slider {
            id: seek
            objectName: "lockMediaSeek"
            width: parent.width
            height: 28 * root.unit
            from: 0; to: 1
            value: session.progress
            enabled: session.canSeek
            Accessible.name: qsTr("Posición de reproducción")
            onPressedChanged: {
                if (pressed) session.beginDrag(value)
                else session.commitDrag(value)
            }
            onMoved: {
                if (pressed) session.dragFraction = value
                else if (root.player) session.seekTo(value * root.player.length)
            }
            background: Rectangle {
                x: seek.leftPadding; y: (seek.height - height) / 2
                width: seek.availableWidth; height: 3 * root.unit
                radius: height / 2; color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                Rectangle { width: parent.width * seek.visualPosition; height: parent.height; radius: parent.radius; color: Theme.accent }
            }
            handle: Rectangle {
                x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                y: (seek.height - height) / 2
                width: 10 * root.unit; height: width; radius: width / 2
                color: Theme.accent
                opacity: seek.hovered || seek.pressed || seek.activeFocus ? 1 : 0
            }
        }
        Item {
            width: parent.width; height: 18 * root.unit * Flags.fontScale
            Text { text: session.formatTime(session.displayPosition); color: Theme.foreground; font.family: Theme.font; font.pixelSize: 11 * root.unit * Flags.fontScale }
            Text { anchors.right: parent.right; text: session.formatTime(root.player?.length || 0); color: Theme.foreground; font.family: Theme.font; font.pixelSize: 11 * root.unit * Flags.fontScale }
        }
    }
    Row {
        id: controls
        objectName: "lockMediaControls"
        x: metadata.x + (metadata.width - width) / 2
        y: (root.showTimeline ? timeline.y + timeline.height : metadata.y + metadata.height) + 12 * root.unit
        spacing: 24 * root.unit
        LockButton { unit: root.unit; flatStyle: true; iconName: "skip_previous"; text: qsTr("Anterior"); enabled: session.canPrevious; onClicked: session.previous() }
        LockButton { unit: root.unit; flatStyle: true; iconName: session.isPlaying ? "pause" : "play_arrow"; text: session.isPlaying ? qsTr("Pausar") : qsTr("Reproducir"); enabled: session.canToggle; onClicked: session.togglePlaying() }
        LockButton { unit: root.unit; flatStyle: true; iconName: "skip_next"; text: qsTr("Siguiente"); enabled: session.canNext; onClicked: session.next() }
    }
}
