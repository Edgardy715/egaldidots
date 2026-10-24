pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "pets"

ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property string scenario: Quickshell.env("ISLA_PET_SCENARIO") || "idle"
    readonly property int seconds: Number(Quickshell.env("ISLA_PET_SECONDS") || "3500")
    property bool measuring: false
    property var intervals: []
    property real lastFrame: 0
    property int frames: 0
    readonly property var runtime: pet.status === Loader.Ready ? pet.item.runtime : null
    readonly property bool animating: runtime !== null && (runtime.reacting || runtime.breathing)
    function report(marker, value) { console.log(marker + " " + JSON.stringify(value)) }
    Window {
        width: 160; height: 100
        visible: true
        title: "Isla Pets performance fixture"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        color: "#202124"
        PetHost {
            id: pet
            anchors.centerIn: parent
            width: 36; height: 36
            requested: root.scenario !== "disabled"
            presented: root.scenario !== "hidden"
            availableWidth: 160; availableHeight: 100
            profile: "balanced"
            onLoaded: item.runtime.sleepDelay = 60000
        }
    }
    onAnimatingChanged: lastFrame = 0
    FrameAnimation {
        running: root.measuring && root.animating
        onTriggered: {
            const now = Date.now()
            if (root.lastFrame > 0) root.intervals.push(now - root.lastFrame)
            root.lastFrame = now
            root.frames++
        }
    }
    Timer {
        interval: 1000; running: true
        onTriggered: {
            const unloaded = root.scenario === "disabled" || root.scenario === "hidden"
            if ((unloaded && (pet.active || pet.item !== null)) || (!unloaded && root.runtime === null)) {
                root.report("PET_ERROR", {error: "unexpected Loader state", scenario: root.scenario})
                Qt.exit(1)
                return
            }
            if (root.scenario === "sleeping") { root.runtime.sleep(); quiet.start() }
            root.measuring = true
            root.report("PET_READY", {scenario: root.scenario, unloaded: unloaded, sleeping: root.runtime ? root.runtime.sleeping : false})
            finish.start()
            if (root.scenario === "reacting") { root.runtime.react(); reactions.start() }
        }
    }
    Timer { id: reactions; interval: 650; repeat: true; onTriggered: root.runtime.react() }
    Timer {
        id: quiet
        interval: 8200
        onTriggered: root.report("PET_QUIET", {sleeping: root.runtime.sleeping,
            breathing: root.runtime.breathing, breath: root.runtime.breath})
    }
    Timer {
        id: finish
        interval: root.seconds
        onTriggered: {
            root.measuring = false
            reactions.stop()
            root.report("PET_RESULT", {scenario: root.scenario, frames: root.frames,
                driverIntervalsMs: root.intervals, unloaded: pet.item === null,
                sleeping: root.runtime ? root.runtime.sleeping : false,
                breathing: root.runtime ? root.runtime.breathing : false})
        }
    }
}
