pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

QtObject {
    id: root
    property bool active: false
    property bool reduced: false
    property bool reactionsEnabled: true
    property string profile: "balanced"
    property int workspaceId: 0
    property bool engaged: false
    property point lookTarget: Qt.point(0, 0)
    property real lookExtent: 1
    property bool initialized: false
    property real impulse: 0
    property int sleepDelay: 45000
    property bool sleeping: false
    property real breath: 0
    readonly property bool motionAllowed: active && !reduced
    readonly property bool reacting: reaction.running
    readonly property bool breathing: sleepBreath.running || breathReturn.running
    readonly property string petState: !active ? "hidden" : sleeping ? "sleeping" : reacting ? "reacting" : engaged ? "observing" : "idle"
    readonly property real lookX: motionAllowed && !sleeping ? Math.max(-1, Math.min(1, lookTarget.x / Math.max(1, lookExtent))) : 0
    readonly property real lookY: motionAllowed && !sleeping ? Math.max(-1, Math.min(1, lookTarget.y / Math.max(1, lookExtent))) : 0

    function settle() {
        reaction.stop()
        sleepBreath.stop()
        breathReturn.stop()
        impulse = 0
        breath = 0
    }
    function armSleep() {
        inactivity.stop()
        if (initialized && active && !engaged && !sleeping) inactivity.start()
    }
    function wake() {
        sleepBreath.stop()
        breathReturn.stop()
        sleeping = false
        if (motionAllowed && breath > 0) breathReturn.start()
        else breath = 0
        armSleep()
    }
    function sleep() {
        if (!initialized || !active || engaged) return
        inactivity.stop()
        settle()
        sleeping = true
        if (motionAllowed && profile !== "minimal") sleepBreath.start()
    }
    function react() {
        if (!initialized || !motionAllowed || !reactionsEnabled || profile === "minimal") return
        reaction.stop()
        reaction.start()
    }
    onWorkspaceIdChanged: { wake(); react() }
    onEngagedChanged: { wake(); if (engaged) react() }
    onActiveChanged: {
        if (active) armSleep()
        else { inactivity.stop(); sleeping = false; settle() }
    }
    onSleepDelayChanged: armSleep()
    onReducedChanged: if (reduced) settle()
    onReactionsEnabledChanged: if (!reactionsEnabled) { reaction.stop(); impulse = 0 }
    onProfileChanged: settle()
    Component.onCompleted: { initialized = true; armSleep() }

    property Timer inactivity: Timer {
        interval: Math.max(1, root.sleepDelay)
        onTriggered: root.sleep()
    }
    property SequentialAnimation sleepBreath: SequentialAnimation {
        loops: 2
        NumberAnimation { target: root; property: "breath"; to: 1; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "breath"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
    }
    property NumberAnimation breathReturn: NumberAnimation {
        target: root; property: "breath"; to: 0
        duration: Motion.standardSmall
        easing.type: Motion.easeStandard
    }

    property SequentialAnimation reaction: SequentialAnimation {
        NumberAnimation { target: root; property: "impulse"; to: 1; duration: Motion.press; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "impulse"; to: 0; duration: Motion.standardLarge; easing.type: Motion.easeStandard }
    }
}
