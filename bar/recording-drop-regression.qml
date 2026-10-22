import QtQuick
import QtTest
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    TestCase {
        id: checks
        name: "RecordingDrop"
        when: Config.loaded
        property bool done: false
        function state(phase, seconds = 83, connected = true) {
            Recording.receive(JSON.stringify({type: "state", connected: connected, phase: phase,
                elapsedSeconds: seconds, busy: false, pauseSupported: true}))
        }
        function until(predicate, message) {
            tryVerify(predicate, 6000, message)
        }
        function shot(name) {
            const output = Quickshell.env("ISLA_TEST_OUTPUT")
            if (!output) return
            findChild(overlay.contentItem, "islandOverlayContent").grabToImage(result => result.saveToFile(output + "/" + name + ".png"))
            wait(100)
        }
        function test_leftRecording() {
            Recording.observe = false
            DesktopStatus.monitorServices = false
            Config.update({appearance: {barLayout: "split", reduceMotion: false}})
            until(() => !overlay.layoutChanging && !overlay.compact, "split settles")
            const pill = findChild(overlay.contentItem, "islandPill")
            const drop = findChild(overlay.contentItem, "islandRecordingCompanion")
            const music = findChild(overlay.contentItem, "islandMediaCompanion")
            const policy = findChild(overlay, "islandInputPolicy")
            verify(pill && drop && music && policy, "overlay integration available")
            pill.notificationsEnabled = false
            state("recording")
            wait(160)
            shot("recording-drop-birth")
            until(() => drop.open && drop.phase === "companion" && drop.settled, "recording separates left")
            verify(pill.recordingDetached && drop.visualX + drop.wPos < pill.x, "recording owns left status")
            compare(drop.elapsedText, "01:23")
            verify(!policy.outsideBodies(drop.visualX + drop.wPos / 2, drop.yPos + drop.hPos / 2), "visual left geometry is clickable")
            compare(policy.maskMode, "pill")
            verify(!overlay.kbFocusWanted, "idle recording keeps keyboard released")
            music.open = true
            until(() => music.phase === "companion" && music.settled, "music separates right")
            verify(music.visualX >= pill.x + pill.width && drop.visualX + drop.wPos < pill.x, "music and recording coexist")
            shot("recording-drops-split")
            state("paused")
            compare(drop.recordingPhase, "paused")
            shot("recording-drop-paused")
            state("offline", 83, false)
            verify(Recording.uncertain && drop.open, "unknown capture remains visible")
            compare(drop.recordingPhase, "unknown")
            shot("recording-drop-unknown")
            state("recording")
            mouseClick(overlay.contentItem, drop.visualX + drop.wPos / 2, drop.yPos + drop.hPos / 2)
            compare(router.openSurface, "recording", "drop opens recording route")
            router.close()
            until(() => drop.open && drop.phase === "companion" && drop.settled, "recording returns after controls")
            router.toggleSurface("", "session")
            until(() => drop.phase === "idle", "session absorbs recording first")
            verify(!pill.recordingDetached, "session restores header status")
            router.close()
            until(() => drop.open && drop.phase === "companion", "recording returns after session")
            router.toggleSurface("", "settings")
            until(() => drop.phase === "idle", "settings suppresses recording")
            verify(!pill.recordingDetached, "settings restores header status")
            router.close()
            until(() => drop.open && drop.phase === "companion", "recording returns after settings")
            music.open = Qt.binding(() => !overlay.layoutChanging && !overlay.compact && !overlay.surfaceOpen)
            Config.update({appearance: {barLayout: "compact"}})
            until(() => !overlay.layoutChanging && overlay.compact, "compact settles with recording")
            until(() => drop.open && drop.phase === "companion" && drop.settled, "compact recording separates")
            verify(drop.visualX + drop.wPos < pill.x, "compact recording stays left")
            verify(Math.abs(drop.yPos + drop.hPos / 2 - pill.y - pill.height / 2) < 1, "compact drop shares bar centerline")
            shot("recording-drop-compact")
            state("stopping")
            compare(drop.recordingPhase, "stopping")
            state("idle", 0)
            wait(160)
            shot("recording-drop-return")
            const x = drop.xPos, velocity = drop.vx
            state("recording")
            compare(drop.xPos, x, "reopen preserves current position")
            compare(drop.vx, velocity, "reopen preserves velocity")
            until(() => drop.phase === "companion" && drop.settled, "interrupted return settles")
            state("idle", 0)
            until(() => drop.phase === "idle" && !drop.active && drop.captureExtra < 0.1, "normal stop fully absorbs")
            verify(!pill.recordingDetached, "absorption restores header ownership")
            state("recording")
            until(() => drop.open && drop.phase === "companion", "recording can restart after absorption")
            Config.update({appearance: {reduceMotion: true}})
            state("idle", 0)
            until(() => drop.phase === "idle" && !pill.recordingDetached, "reduced stop resolves")
            state("idle", 0)
            Recording.countdownDeadline = Date.now() + 3000
            Recording.countdown = 3
            until(() => drop.open, "countdown is detached")
            compare(drop.recordingPhase, "countdown")
            Recording.cancelCountdown()
            Recording.pendingAction = "start"
            until(() => drop.open, "starting remains detached")
            compare(drop.recordingPhase, "starting")
            state("recording")
            const previousMonitors = policy.monitors
            policy.monitors = [{name: overlay.modelData.name, activeWorkspace: {lastIpcObject: {hasfullscreen: true}}}]
            until(() => drop.phase === "idle", "fullscreen absorbs recording")
            compare(policy.maskMode, "hidden")
            verify(!pill.recordingDetached && !overlay.kbFocusWanted, "fullscreen releases status and input")
            policy.monitors = previousMonitors
            until(() => drop.open, "recording returns after fullscreen")
            pill.width = overlay.width - 16
            until(() => !drop.open && drop.phase === "idle", "narrow space absorbs drop")
            verify(!pill.recordingDetached && Recording.engaged, "narrow space retains header recording")
            state("idle", 0)
            verify(!Recording.observe, "fixture never starts backend")
            console.log("PASS: recording left drop, music coexistence, click route, phases, session/settings fallback, split/compact, interruption, reduced motion and narrow fallback")
            done = true
        }
    }
    Timer { interval: 150; running: checks.done; onTriggered: Qt.quit() }
}
