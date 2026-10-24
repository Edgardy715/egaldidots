import QtQuick
import Quickshell
import "components"
import "pets"
import "Singletons"

ShellRoot {
    id: root
    settings.watchFiles: false
    property bool playerPresent: false
    property bool playerPlaying: false
    property real exposedOnOverlap: 0
    property real maxCapture: 0
    property real maxPillWidthDelta: 0
    property real pillWidthAtRest: 0

    Window {
        width: 800; height: 100
        visible: true
        color: "#202124"
        PetLayer { id: pet; monitorActive: true }
        Pill {
            id: pill
            x: 300; y: 8
            petContext: pet
            petVisible: pet.petVisible
        }
        FluidMediaCompanion {
            id: drop
            anchors.fill: parent
            body: pill
            petContext: pet
            open: root.playerPresent
            compactWidth: root.playerPlaying ? playingW : collapsedW
            mediaPlaying: root.playerPlaying
        }
    }
    FrameAnimation {
        running: drop.phase !== "idle" && pet.perchId === "bar"
        onTriggered: {
            root.maxCapture = Math.max(root.maxCapture, drop.captureExtra, drop.captureTarget)
            if (drop.phase === "retornando") {
                root.maxPillWidthDelta = Math.max(root.maxPillWidthDelta,
                    Math.abs(pill.width - root.pillWidthAtRest))
            }
            if (drop.overlapsBody)
                root.exposedOnOverlap = Math.max(root.exposedOnOverlap, drop.contentExposure)
        }
    }
    property int step: 0
    property real started: Date.now()
    function advance() { step++; started = Date.now() }
    function fail(reason) {
        console.error("FAIL: " + reason + " " + JSON.stringify({step: step, phase: drop.phase,
            perch: pet.perchId, nicheAnimating: pill.petNicheAnimating,
            exposure: exposedOnOverlap, capture: maxCapture, pillDelta: maxPillWidthDelta}))
        Qt.exit(1)
    }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            if (!Config.loaded) return
            if (Date.now() - root.started > (root.step === 4 || root.step === 8 ? 2500 : 5000)) {
                root.fail("timeout"); return
            }
            if (root.step === 0) {
                Config.update({pets: {enabled: true}, appearance: {barLayout: "split", reduceMotion: false}})
                root.advance()
            } else if (root.step === 1 && pet.perchId === "bar" && pet.petVisible && !pill.petNicheAnimating) {
                root.exposedOnOverlap = 0; root.maxCapture = 0
                root.playerPresent = true; root.playerPlaying = true; root.advance()
            } else if (root.step === 2 && drop.phase === "companion" && !pill.petNicheAnimating) {
                if (root.exposedOnOverlap >= 0.01 || root.maxCapture >= 0.5) {
                    root.fail("awake separation geometry"); return
                }
                root.playerPlaying = false; root.advance()
            } else if (root.step === 3 && Date.now() - root.started > 200) {
                if (drop.phase !== "companion") { root.fail("pause absorbed drop"); return }
                root.exposedOnOverlap = 0; root.maxCapture = 0; root.maxPillWidthDelta = 0
                root.pillWidthAtRest = pill.width
                root.playerPresent = false; root.advance()
            } else if (root.step === 4 && drop.phase === "idle") {
                if (pill.petNicheAnimating || root.exposedOnOverlap >= 0.01
                        || root.maxCapture >= 0.5 || root.maxPillWidthDelta >= 0.5) {
                    root.fail("awake gather geometry"); return
                }
                console.log("awake gather: exposure=" + root.exposedOnOverlap
                    + " capture=" + root.maxCapture + " pillDelta=" + root.maxPillWidthDelta)
                pet.actor.sleepNow(); root.advance()
            } else if (root.step === 5 && pet.actor.asleep && !pill.petNicheAnimating) {
                root.exposedOnOverlap = 0; root.maxCapture = 0
                root.playerPresent = true; root.playerPlaying = true; root.advance()
            } else if (root.step === 6 && drop.phase === "companion" && !pill.petNicheAnimating) {
                if (root.exposedOnOverlap >= 0.01 || root.maxCapture >= 0.5) {
                    root.fail("sleeping separation geometry"); return
                }
                root.playerPlaying = false; root.advance()
            } else if (root.step === 7 && Date.now() - root.started > 200) {
                if (drop.phase !== "companion") { root.fail("sleeping pause absorbed drop"); return }
                root.exposedOnOverlap = 0; root.maxCapture = 0; root.maxPillWidthDelta = 0
                root.pillWidthAtRest = pill.width
                root.playerPresent = false; root.advance()
            } else if (root.step === 8 && drop.phase === "idle") {
                if (pill.petNicheAnimating || root.exposedOnOverlap >= 0.01
                        || root.maxCapture >= 0.5 || root.maxPillWidthDelta >= 0.5) {
                    root.fail("sleeping gather geometry"); return
                }
                console.log("sleeping gather: exposure=" + root.exposedOnOverlap
                    + " capture=" + root.maxCapture + " pillDelta=" + root.maxPillWidthDelta)
                console.log("PASS: media arrival, pause and absorption with awake/sleeping Mimo")
                Qt.quit()
            }
        }
    }
}
