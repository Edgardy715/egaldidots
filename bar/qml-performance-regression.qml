// Run through tests/qml-performance.py for isolated services and counters.
import QtQuick
import Quickshell
import "components"
import "surfaces"
import "windows"
import "Singletons"
import "tests/PerfCounters.js" as Perf

ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property bool baseline: Quickshell.env("ISLA_PERF_BASELINE") === "1"
    property int playbackChanges: 0
    property string titleProbe: Perf.title(media.playback.title)
    property bool done: false
    Window {
        id: scene
        visible: true
        width: 760; height: 540
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        MediaSurface { id: media; open: true; morphCloseness: 1 }
        IslandMediaVisualizer {
            id: wave
            x: 15; y: 15
            hasMedia: true; isPlaying: true; hasFrame: true
            values: Array(24).fill(0.4)
        }
    }
    Connections { target: media; function onPlaybackChanged() { root.playbackChanges++ } }
    Timer {
        interval: 16; running: true; repeat: true
        property int tick: 0
        onTriggered: wave.values = Array(24).fill((++tick % 50) / 50)
    }
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    Timer {
        id: checks
        interval: 100; repeat: true; running: Config.loaded
        property int step: 0
        property int ticks: 0
        property var result: ({})
        property var pill: null
        property var companion: null
        property var policy: null
        property var light: null
        property var monitors: null
        property int changes: 0
        property int reads: 0
        property int bands: 0
        property real position: 0
        property real phase: 0
        function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
        function glow(item) {
            if (item.driftPhase !== undefined) return item
            for (const child of item.children || []) { const found = glow(child); if (found) return found }
            return null
        }
        onTriggered: {
            if (++ticks > 300) { check(false, "fixture timed out at step " + step); return }
            if (step === 0) {
                Recording.observe = false
                DesktopStatus.monitorServices = false
                Config.update({appearance: {barLayout: "split", reduceMotion: false}})
                pill = overlay.contentItem.children.find(child => child.objectName === "islandOverlayContent")
                pill = pill.children.find(child => child.objectName === "islandPill")
                companion = overlay.contentItem.children.find(child => child.objectName === "islandOverlayContent")
                companion = companion.children.find(child => child.objectName === "islandMediaCompanion")
                policy = overlay.perfPolicy
                check(!!pill && !!companion && !!policy, "overlay objects available")
                pill.notificationsEnabled = false
                step = 1
            } else if (step === 1) {
                if (companion.phase !== "companion" || !companion.settled) return
                light = glow(pill)
                check(light !== null, "pill glow exists")
                console.log("QML_READY")
                changes = root.playbackChanges; reads = Perf.metadata; bands = Perf.bands
                position = media.playback.displayPosition
                ticks = 0; step = 2
            } else if (step === 2 && ticks >= 10) {
                result = { playbackChanges: root.playbackChanges - changes,
                    metadataReads: Perf.metadata - reads, visibleBandCalls: Perf.bands - bands }
                check(media.playback.displayPosition > position + 0.7, "clock advances")
                check(root.titleProbe === "Fixed metadata", "metadata intact")
                wave.visible = false
                ticks = 0; step = 3
            } else if (step === 3 && ticks >= 2) {
                bands = Perf.bands; ticks = 0; step = 4
            } else if (step === 4 && ticks >= 10) {
                result.hiddenBandCalls = Perf.bands - bands
                monitors = policy.monitors
                policy.monitors = [{name: overlay.modelData.name, activeWorkspace: {lastIpcObject: {hasfullscreen: true}}}]
                ticks = 0; step = 5
            } else if (step === 5) {
                if (pill.opacity >= 0.001 || ticks < 5) return
                phase = light.driftPhase; ticks = 0; step = 6
            } else if (step === 6 && ticks >= 3) {
                result.fullscreenGlowAdvanced = light.driftPhase !== phase
                result.fullscreenCavaActive = !!Cava.consumers[companion.cavaConsumerId]
                if (!root.baseline) {
                    check(result.playbackChanges === 0, "playback identity stable")
                    check(result.metadataReads === 0, "static metadata is not reevaluated")
                    check(result.hiddenBandCalls === 0, "hidden spectrum does no work")
                    check(!result.fullscreenGlowAdvanced, "fullscreen glow pauses")
                    check(!result.fullscreenCavaActive, "fullscreen consumer releases")
                }
                policy.monitors = monitors
                ticks = 0; step = 7
            } else if (step === 7) {
                if (!pill.visible || pill.opacity < 0.999 || !companion.visible) return
                check(!!Cava.consumers[companion.cavaConsumerId], "consumer resumes")
                phase = light.driftPhase; wave.visible = true; bands = Perf.bands
                ticks = 0; step = 8
            } else if (step === 8 && ticks >= 2) {
                check(light.driftPhase !== phase, "glow resumes")
                check(Perf.bands > bands, "spectrum resumes")
                Config.update({appearance: {reduceMotion: true}})
                phase = light.driftPhase; ticks = 0; step = 9
            } else if (step === 9 && ticks >= 2) {
                check(light.driftPhase === phase, "reduced glow remains still")
                Players.fixture.isPlaying = false
                Players.fixture.position = 75
                Players.fixture.trackTitle = "Updated metadata"
                ticks = 0; step = 10
            } else if (step === 10 && ticks >= 2) {
                check(root.titleProbe === "Updated metadata", "metadata changes propagate")
                check(media.playback.displayPosition === 75, "external seek propagates")
                check(media.playback.displayTime === "1:15", "formatted position intact")
                check(media.playback.remainingTime === "2:45", "formatted remaining intact")
                if (Quickshell.env("ISLA_TEST_OUTPUT"))
                    scene.contentItem.grabToImage(image => image.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/media.png"))
                console.log("QML_PERF " + JSON.stringify(result))
                console.log("PASS: QML performance measurement, clock, metadata, fullscreen release/resume, reduced")
                stop(); root.done = true
            }
        }
    }
    Timer { interval: 100; running: root.done; onTriggered: Qt.quit() }
}
