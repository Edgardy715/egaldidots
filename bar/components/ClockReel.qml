import QtQuick
import "../Singletons"

// Odometer for clock digits. Only the digits that change roll, the ones digit first; the old
// glyph drops and fades while the new one settles in from above. The travel stays inside the
// glyph's own line, so a roll never crosses the glass rim (the old reel slid a full pill height).
Item {
    id: root
    property string text: ""
    property font font
    property color color: Theme.foreground
    property string widthSample: "00"
    property bool motionEnabled: visible && !Flags.reduceMotion
    // 1: the new value settles in from above (counting up); -1: from below.
    property int direction: 1
    property int rollDirection: 1
    // Roll length; a roll queued behind another (keys held, values ticking) runs faster so the
    // reel keeps up instead of trailing the value by several rolls.
    property int duration: Motion.standardLarge
    property int burstDuration: Math.round(duration * 0.45)
    property bool chained: false
    // Horizontal placement of the digit cells inside the reserved width (widthSample).
    property int alignment: Qt.AlignHCenter
    // Numbers: the roll direction follows the value (up settles from above, down from below).
    property bool numericDirection: false
    property string shown: ""
    property string incoming: ""
    property real travel: 0
    property bool ready: false
    readonly property bool animating: roll.running
    // Tabular digits share one advance: a fixed cell per character keeps still digits still.
    readonly property int cells: Math.max(shown.length, incoming.length)
    readonly property real cellWidth: metrics.advanceWidth / Math.max(1, widthSample.length)
    // Rolling distance: half a line, enough to read as a roll, never past the pill's core.
    readonly property real drop: fontMetrics.height * 0.5
    // The ones digit leads; each digit to its left follows this share of the roll later.
    readonly property real lag: 0.12
    implicitWidth: metrics.advanceWidth
    implicitHeight: metrics.height
    baselineOffset: (height - fontMetrics.height) / 2 + fontMetrics.ascent
    Accessible.ignored: true
    TextMetrics { id: metrics; font: root.font; text: root.widthSample }
    FontMetrics { id: fontMetrics; font: root.font }
    function update() {
        if (!ready || !motionEnabled) {
            roll.stop()
            shown = text
            incoming = text
            travel = 0
            return
        }
        if (roll.running) return
        if (shown === text) { chained = false; return }
        incoming = text
        travel = 0
        if (numericDirection) {
            const from = parseFloat(shown), to = parseFloat(incoming)
            rollDirection = isFinite(from) && isFinite(to) && to < from ? -1 : 1
        } else {
            rollDirection = direction < 0 ? -1 : 1
        }
        roll.start()
    }
    onTextChanged: update()
    onMotionEnabledChanged: update()
    Component.onCompleted: { shown = text; incoming = text; ready = true }
    NumberAnimation {
        id: roll
        target: root; property: "travel"
        from: 0; to: 1
        duration: root.chained ? root.burstDuration : root.duration
        easing.type: Easing.Linear
        onFinished: {
            root.chained = root.text !== root.incoming
            root.shown = root.incoming
            root.travel = 0
            Qt.callLater(root.update)
        }
    }
    Repeater {
        model: root.cells
        Item {
            id: cell
            required property int index
            // Strings of different length (9 -> 10) roll whole; otherwise digit by digit.
            readonly property bool sameLength: root.shown.length === root.incoming.length
            readonly property string from: sameLength ? root.shown.charAt(index) : (index === 0 ? root.shown : "")
            readonly property string to: sameLength ? root.incoming.charAt(index) : (index === 0 ? root.incoming : "")
            readonly property bool rolling: root.animating && from !== to
            readonly property real start: root.lag * (root.cells - 1 - index)
            readonly property real t: rolling ? Math.max(0, Math.min(1, (root.travel - start) / (1 - root.lag * (root.cells - 1)))) : 0
            // The old glyph accelerates away; the new one decelerates in, overlapping briefly.
            readonly property real outgoing: Math.pow(Math.min(1, t / 0.6), 2)
            readonly property real arriving: 1 - Math.pow(1 - Math.max(0, (t - 0.25) / 0.75), 3)
            readonly property real lead: root.alignment & Qt.AlignLeft ? 0
                : root.alignment & Qt.AlignRight ? root.width - root.cells * root.cellWidth
                : (root.width - root.cells * root.cellWidth) / 2
            x: sameLength ? lead + index * root.cellWidth : 0
            width: sameLength ? root.cellWidth : root.width
            height: root.height
            Text {
                width: parent.width; height: parent.height
                y: root.drop * root.rollDirection * cell.outgoing
                opacity: 1 - cell.outgoing
                visible: opacity > 0.001
                text: cell.from; font: root.font; color: root.color
                horizontalAlignment: cell.sameLength ? Text.AlignHCenter : (root.alignment & Qt.AlignLeft ? Text.AlignLeft : Text.AlignRight); verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: parent.width; height: parent.height
                y: -root.drop * root.rollDirection * (1 - cell.arriving)
                opacity: cell.arriving
                visible: cell.rolling
                text: cell.to; font: root.font; color: root.color
                horizontalAlignment: cell.sameLength ? Text.AlignHCenter : (root.alignment & Qt.AlignLeft ? Text.AlignLeft : Text.AlignRight); verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
