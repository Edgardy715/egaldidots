pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "pets"

/**
 * Bounded pet benchmark fixture. Counts frames the window really presents
 * (frameSwapped), which forces no rendering, unlike a FrameAnimation driver.
 * ISLA_PET_IMPL=mimo (default) measures the perch runtime; "legacy" loads the
 * old PetHost by URL, which only works with the archived files restored from
 * docs/eshell-pets-2026-10-22/legacy-code/ (it then reports PET_ERROR otherwise).
 */
ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property string impl: Quickshell.env("ISLA_PET_IMPL") || "mimo"
    readonly property string scenario: Quickshell.env("ISLA_PET_SCENARIO") || "idle"
    readonly property int seconds: Number(Quickshell.env("ISLA_PET_SECONDS") || "3500")
    readonly property bool legacy: impl === "legacy"
    readonly property bool loaded: scenario !== "disabled" && (legacy ? scenario !== "hidden" : true)
    property bool measuring: false
    property int frames: 0
    property int flightStarts: 0
    // PetHost is itself a Loader: its item is the character that owns the runtime.
    readonly property var legacyRuntime: legacyPet.item && legacyPet.item.petVisible ? legacyPet.item.item.runtime : null
    readonly property Item actor: layerLoader.item ? layerLoader.item.actor : null
    onActorChanged: if (actor && (scenario === "idle" || scenario === "rail-idle")) {
        // Keep spontaneous walks/yawns out of the idle sample; they have separate scenarios.
        actor.random = () => 0.99
        actor.armBrain()
    }

    function report(marker, value) { console.log(marker + " " + JSON.stringify(value)) }
    function state() {
        if (legacy) return {sleeping: legacyRuntime ? legacyRuntime.sleeping : false,
                            breathing: legacyRuntime ? legacyRuntime.breathing : false}
        return {shown: actor ? actor.shown : false, anim: actor ? actor.anim : "",
                asleep: actor ? actor.asleep : false, settled: actor ? actor.settled : false}
    }

    Window {
        id: window
        width: 200; height: 100
        visible: true
        title: "Isla Pets performance fixture"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        color: "#202124"
        onFrameSwapped: if (root.measuring) root.frames++

        Loader {
            id: legacyPet
            anchors.centerIn: parent
            width: 36; height: 36
            active: root.legacy && root.loaded
            source: "pets/PetHost.qml"
            onLoaded: {
                item.requested = true
                item.presented = true
                item.availableWidth = 160
                item.availableHeight = 100
            }
        }

        Loader {
            id: layerLoader
            active: !root.legacy && root.loaded
            sourceComponent: PetLayer { monitorActive: true; coding: root.scenario === "coding" }
        }
        PetPerch {
            id: bench
            x: 20; y: 20
            width: 160; height: 60
            petLayer: layerLoader.item
            perchId: root.scenario === "coding" ? "bar" : "bench"
            kind: "line"
            available: root.scenario !== "hidden" && root.scenario !== "rail-idle"
            mood: root.scenario === "dancing" ? "music" : ""
        }
        PetPerch {
            id: flightDestination
            x: 20; y: 20; width: 160; height: 60
            petLayer: layerLoader.item
            perchId: "destination"; priority: 1; kind: "line"
            minX: 140; maxX: 140
            available: false
        }
        Loader {
            active: root.scenario === "rail-idle"
            source: active ? "components/TopWorkspaceRail.qml" : ""
            onLoaded: {
                item.petLayer = Qt.binding(() => layerLoader.item)
                item.integrated = true
                item.availableWidth = 180
                item.style = "pet"
                item.x = 10; item.y = 20
            }
        }
    }

    Timer {
        id: ready
        interval: (root.scenario === "sleeping" && !root.legacy) || root.scenario === "coding" ? 6500 : 1000
        running: true
        onTriggered: {
            if (root.loaded && !root.legacy && (root.actor === null || (root.scenario !== "hidden") !== root.actor.shown)) {
                root.report("PET_ERROR", {error: "unexpected actor state", scenario: root.scenario, state: root.state()})
                Qt.exit(1)
                return
            }
            if (root.legacy && root.loaded && root.legacyRuntime === null) {
                root.report("PET_ERROR", {error: "legacy PetHost unavailable", scenario: root.scenario})
                Qt.exit(1)
                return
            }
            if (root.scenario === "coding" && !root.actor.settled) {
                root.report("PET_ERROR", {error: "code has not settled", state: root.state()})
                Qt.exit(1)
                return
            }
            if (root.legacy && root.loaded) root.legacyRuntime.sleepDelay = 60000
            if (root.legacy && root.scenario === "sleeping") root.legacyRuntime.sleep()
            root.measuring = true
            root.report("PET_READY", {impl: root.impl, scenario: root.scenario, state: root.state()})
            finish.start()
            if (root.scenario === "reacting") reactions.start()
            if (root.scenario === "walking") walker.start()
            if (root.scenario === "flying") {
                flightDestination.available = true
                root.flightStarts = 1
                flights.start()
            }
        }
    }
    // Mimo sleeps before measuring so the window covers the settled pose.
    Timer {
        interval: 500; running: root.scenario === "sleeping" && !root.legacy
        onTriggered: if (root.actor) root.actor.sleepNow()
    }
    Timer {
        id: flights
        interval: 1000; repeat: true
        onTriggered: {
            flightDestination.available = !flightDestination.available
            root.flightStarts++
        }
    }
    Timer {
        id: reactions
        interval: 650; repeat: true
        onTriggered: root.legacy ? root.legacyRuntime.react() : root.actor.act("click")
    }
    Timer {
        id: walker
        interval: 250; repeat: true
        onTriggered: if (root.actor.walkDir === 0)
            root.actor.walkTo(root.actor.centerX < 80 ? 150 : 10)
    }
    Timer {
        id: finish
        interval: root.seconds
        onTriggered: {
            root.measuring = false
            reactions.stop()
            walker.stop()
            flights.stop()
            root.report("PET_RESULT", {impl: root.impl, scenario: root.scenario, frames: root.frames,
                framesPerSecond: root.frames / (root.seconds / 1000), flightStarts: root.flightStarts, state: root.state()})
        }
    }
}
