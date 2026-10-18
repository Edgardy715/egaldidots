import QtQuick
import "../"
import "../Singletons"
import "../Singletons/Spectrum.js" as Spectrum

/** Five-band Cava waveform used beside the compact media chip. */
Item {
    id: root
    property color musicAccent: Theme.accent

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
        scale: hit.motion.visualScale
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        spacing: 2.5 * root.s

        Repeater {
            model: 5
            delegate: Item {
                required property int index
                readonly property real minHeight: 2.5 * root.s
                readonly property real maxHeight: 18 * root.s
                readonly property real signal: root.isPlaying && root.hasFrame && !Flags.reduceMotion
                    ? Spectrum.band(root.values, index, 5) : 0
                width: 2.5 * root.s
                height: root.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Keep the audio axis exact; centered anchors round fractional geometry.
                    y: (parent.height - height) / 2
                    width: parent.width
                    height: parent.minHeight + parent.signal * (parent.maxHeight - parent.minHeight)
                    radius: width / 2
                    antialiasing: true
                    color: Qt.alpha(root.musicAccent, 0.88)
                }
            }
        }
    }

    MotionArea {
        id: hit
        accessibleName: qsTr("Abrir controles multimedia")
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestMedia()
    }
}
