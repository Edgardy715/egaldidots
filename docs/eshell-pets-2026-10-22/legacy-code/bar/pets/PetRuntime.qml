pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

QtObject {
    id: root
    property bool active: false
    property bool reduced: false
    property bool reactionsEnabled: true
    property bool resting: false
    property bool sleepEnabled: true
    property bool gazeEnabled: true
    property bool feedingEnabled: true
    property bool eating: false
    property real chew: 0
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
    readonly property string petState: !active ? "hidden" : eating ? "eating" : sleeping ? "sleeping" : reacting ? "reacting" : engaged ? "observing" : "idle"
    readonly property real lookX: motionAllowed && gazeEnabled && !sleeping ? Math.max(-1, Math.min(1, lookTarget.x / Math.max(1, lookExtent))) : 0
    readonly property real lookY: motionAllowed && gazeEnabled && !sleeping ? Math.max(-1, Math.min(1, lookTarget.y / Math.max(1, lookExtent))) : 0

    function settle() {
        meal.stop()
        chewing.stop()
        eating = false
        chew = 0
        reaction.stop()
        sleepBreath.stop()
        breathReturn.stop()
        impulse = 0
        breath = 0
    }
    function armSleep() {
        inactivity.stop()
        if (initialized && active && sleepEnabled && !engaged && !sleeping && !eating) inactivity.start()
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
        if (!initialized || !active || !sleepEnabled || engaged || eating) return
        inactivity.stop()
        settle()
        sleeping = true
        if (motionAllowed && profile !== "minimal") sleepBreath.start()
    }
    function react() {
        if (!initialized || eating || !motionAllowed || !reactionsEnabled || profile === "minimal") return
        reaction.stop()
        reaction.start()
    }
    function feed() {
        if (!initialized || !active || !feedingEnabled || eating) return
        settle()
        wake()
        eating = true
        inactivity.stop()
        meal.start()
        if (motionAllowed && profile !== "minimal") chewing.start()
    }
    function notify(kind) {
        if (!initialized || !active || !["media.started", "media.paused", "media.track",
                "wallpaper.selection", "wallpaper.applied"].includes(kind)) return
        wake()
        if (kind === "media.paused") { reaction.stop(); impulse = 0 }
        else react()
    }
    onWorkspaceIdChanged: { wake(); react() }
    onEngagedChanged: { wake(); if (engaged) react() }
    onActiveChanged: {
        if (active) armSleep()
        else { inactivity.stop(); sleeping = false; settle() }
    }
    onSleepDelayChanged: armSleep()
    onSleepEnabledChanged: { if (!sleepEnabled) wake(); else armSleep() }
    onFeedingEnabledChanged: if (!feedingEnabled && eating) { settle(); armSleep() }
    onReducedChanged: if (reduced) { settle(); armSleep() }
    onReactionsEnabledChanged: if (!reactionsEnabled) { reaction.stop(); impulse = 0 }
    onProfileChanged: { settle(); armSleep() }
    Component.onCompleted: { initialized = true; armSleep() }

    property Timer meal: Timer {
        interval: 1600
        onTriggered: { root.eating = false; root.chewing.stop(); root.chew = 0; root.armSleep() }
    }
    property SequentialAnimation chewing: SequentialAnimation {
        loops: 4
        NumberAnimation { target: root; property: "chew"; to: 1; duration: 200; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "chew"; to: 0; duration: 200; easing.type: Easing.InOutSine }
    }
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
