import QtQuick
import "../Singletons"

/** Compact cover and truncated metadata used by media headers. */
Item {
    id: root

    property real s: 1
    property real coverDiameter: 34
    property real textWidth: 200
    property real spacing: 10
    property real metadataSpacing: 3
    property real titlePixelSize: 12.5
    property real artistPixelSize: 11
    property string artUrl: ""
    property string title: ""
    property string artist: ""
    property bool showArtist: true
    property real progress: 0
    property bool hasProgress: false

    implicitWidth: coverDiameter + spacing + textWidth
    implicitHeight: coverDiameter
    width: implicitWidth
    height: implicitHeight

    IslandMediaCover {
        id: cover
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        s: root.s
        diameter: root.coverDiameter
        artUrl: root.artUrl
        hasProgress: root.hasProgress
        progress: root.progress
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: root.spacing
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        spacing: root.metadataSpacing

        AnimatedLabel {
            width: parent.width
            value: root.title
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: root.titlePixelSize
            font.weight: Font.Medium
        }
        AnimatedLabel {
            width: parent.width
            value: root.artist
            visible: root.showArtist
            elide: Text.ElideRight
            color: Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: root.artistPixelSize
        }
    }
}
