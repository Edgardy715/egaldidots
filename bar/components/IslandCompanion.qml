pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// Original expression for Isla, driven by interaction rather than an idle loop.
Item {
    id: root
    property real s: 1
    property bool reduced: Flags.reduceMotion
    property string mood: "rest"
    property bool engaged: false
    property real lookX: 0
    property real lookY: 0
    property real lid: 1
    readonly property bool smiling: mood === "received" || mood === "connected" || mood === "finished"
    readonly property bool resting: mood === "paused"
    property real gazeX: reduced ? 0 : Math.max(-1, Math.min(1, lookX)) * 3 * s
    property real gazeY: reduced ? 0 : Math.max(-1, Math.min(1, lookY)) * 1.8 * s
    width: 30 * s; height: 26 * s
    Accessible.ignored: true

    function greet() {
        if (reduced || !visible || cooldown.running) return
        blink.restart()
        cooldown.restart()
    }
    function settle() { blink.stop(); cooldown.stop(); gazeXMotion.complete(); gazeYMotion.complete(); lid = 1 }
    onReducedChanged: if (reduced) settle()
    onVisibleChanged: if (!visible) settle()
    onMoodChanged: if (mood !== "rest") greet()
    Behavior on gazeX { enabled: !root.reduced && root.visible; SpringAnimation { id: gazeXMotion; spring: 4; damping: 0.4; epsilon: 0.01 } }
    Behavior on gazeY { enabled: !root.reduced && root.visible; SpringAnimation { id: gazeYMotion; spring: 4; damping: 0.4; epsilon: 0.01 } }
    Timer { id: cooldown; interval: 2400 }
    SequentialAnimation {
        id: blink
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 70 }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    Repeater {
        model: 2
        Rectangle {
            required property int index
            x: (index === 0 ? 7 : 18) * root.s + root.gazeX
            y: (root.height - height) / 2 + root.gazeY
            width: (root.smiling || root.resting ? 7 : 5) * root.s
            height: (root.smiling ? 3.5 : root.resting ? 2.2 : root.mood === "working" ? 7 : root.engaged ? 11 : 10) * root.s
            radius: width / 2
            color: root.mood === "attention" ? Theme.accentStrong : Theme.foreground
            transform: Scale { origin.x: 3 * root.s; origin.y: 5 * root.s; yScale: root.lid }
            rotation: root.smiling ? (index === 0 ? -12 : 12) : 0
            Behavior on width { enabled: !root.reduced && root.visible; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
            Behavior on height { enabled: !root.reduced && root.visible; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
            Behavior on rotation { enabled: !root.reduced && root.visible; NumberAnimation { duration: Motion.standardSmall } }
        }
    }
}
