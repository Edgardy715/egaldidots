import QtQuick
import "../"
import "../Singletons"

/** Five-band Cava waveform used beside the compact media chip. */
Item {
    id: root

    property real s: 1
    property real coreH: 38
    property bool hiddenForAuth: false
    property bool hasMedia: false
    property bool isPlaying: false
    property bool hasFrame: false
    property var values: []
    signal requestMedia()

    width: hasMedia && !hiddenForAuth ? 26 * s : 0
    height: coreH
    clip: true
    visible: hasMedia && !hiddenForAuth
    opacity: visible ? 1 : 0
    Behavior on width { Anim { type: Anim.Morph } }
    Behavior on opacity { Anim { type: Anim.DefaultEffects } }

    Row {
        anchors.centerIn: parent
        spacing: 2.5 * root.s

        Repeater {
            model: 5
            delegate: Item {
                required property int index
                readonly property var profile: [0.35, 0.70, 1.00, 0.70, 0.35]
                readonly property var bands: [2, 7, 12, 16, 21]
                readonly property real minHeight: 2.5 * root.s
                readonly property real maxHeight: profile[index] * 18 * root.s
                readonly property real signal: root.isPlaying && root.hasFrame
                    ? (root.values[bands[index]] || 0) : 0
                width: 2.5 * root.s
                height: root.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: parent.minHeight + parent.signal * (parent.maxHeight - parent.minHeight)
                    radius: width / 2
                    color: Qt.alpha(Theme.accent, 0.72 + parent.signal * 0.28)
                    Behavior on height { Anim { type: Anim.FastEffects } }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestMedia()
    }
}
