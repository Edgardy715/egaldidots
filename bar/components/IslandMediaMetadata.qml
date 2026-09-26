import QtQuick
import "../Singletons"

/** Seamless title/artist marquee for the compact media chip. */
Item {
    id: root

    property real s: 1
    property real contentWidth: 132
    property real coreH: 38
    property string title: "—"
    property string artist: ""
    property bool playing: false

    width: contentWidth
    height: coreH
    clip: true

    function escapeText(text) {
        return ("" + text).replace(/&/g, "&" + "amp;")
            .replace(/</g, "&" + "lt;").replace(/>/g, "&" + "gt;")
    }

    readonly property string richText: {
        let result = "<span style='color:" + ("" + Theme.foreground)
            + ";font-weight:500'>" + escapeText(title || "—") + "</span>"
        if (artist.length > 0)
            result += "<span style='color:" + ("" + Theme.dim) + "'>   " + escapeText(artist) + "</span>"
        return result
    }
    readonly property bool overflow: marqueeText.implicitWidth > width

    function reset() {
        marquee.scrollX = 0
        marquee.armed = false
    }

    Item {
        id: marquee
        anchors.verticalCenter: parent.verticalCenter
        height: root.height
        property real scrollX: 0
        property bool armed: false
        readonly property real separator: 40 * root.s

        Text {
            id: marqueeText
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.RichText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
            font.letterSpacing: 0.05 * root.s
            text: root.richText
            x: root.overflow ? marquee.scrollX : (root.width - implicitWidth) / 2
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.RichText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
            font.letterSpacing: 0.05 * root.s
            text: root.richText
            x: marqueeText.x + marqueeText.implicitWidth + marquee.separator
            visible: root.overflow && marquee.armed
        }
        Timer {
            interval: 700
            running: root.overflow && root.playing && root.visible
            onTriggered: marquee.armed = true
        }
        NumberAnimation on scrollX {
            from: 0
            to: -(marqueeText.implicitWidth + marquee.separator)
            duration: Math.max(2200, Math.round((marqueeText.implicitWidth + marquee.separator) / 0.045))
            loops: Animation.Infinite
            running: root.overflow && marquee.armed && root.playing && root.visible
            easing.type: Easing.Linear
        }
    }

    onRichTextChanged: reset()
}
