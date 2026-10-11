import QtQuick
import "../Singletons"

Item {
    id: root
    property string text: ""
    property font font
    property color color: Theme.foreground
    property string widthSample: "00"
    property bool motionEnabled: visible && !Flags.reduceMotion
    property string shown: ""
    property string incoming: ""
    property real travel: 0
    property bool ready: false
    readonly property bool animating: roll.running
    implicitWidth: metrics.advanceWidth
    implicitHeight: metrics.height
    clip: true
    Accessible.ignored: true
    TextMetrics { id: metrics; font: root.font; text: root.widthSample }
    function update() {
        if (!ready || !motionEnabled) {
            roll.stop()
            shown = text
            incoming = text
            travel = 0
            return
        }
        if (roll.running || shown === text) return
        incoming = text
        travel = 0
        roll.start()
    }
    onTextChanged: update()
    onMotionEnabledChanged: update()
    Component.onCompleted: { shown = text; incoming = text; ready = true }
    NumberAnimation {
        id: roll
        target: root; property: "travel"
        from: 0; to: 1
        duration: Motion.emphasizedLarge
        easing.type: Motion.easeStandard
        onFinished: {
            root.shown = root.incoming
            root.travel = 0
            Qt.callLater(root.update)
        }
    }
    Text {
        width: root.width; height: root.height
        y: root.travel * height
        text: root.shown; font: root.font; color: root.color
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    Text {
        width: root.width; height: root.height
        y: (root.travel - 1) * height
        visible: roll.running
        text: root.incoming; font: root.font; color: root.color
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
}
