import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"
import "surfaces"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 1000; height: 820
        color: Theme.background
        Pill { id: pill; y: 32; anchors.horizontalCenter: parent.horizontalCenter; notificationsEnabled: false; screenName: "recording-fixture" }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property int saves: 0
            property bool done: false
            Connections { target: Recording; function onSaved(path) { checks.saves++ } }
            function check(ok, message) { if (!ok) throw new Error(message) }
            function state(phase, seconds, connected = true, path = "") {
                Recording.receive(JSON.stringify({type: "state", connected: connected, phase: phase,
                    elapsedSeconds: seconds, outputPath: path, busy: false, pauseSupported: true, setupRequired: !connected}))
            }
            function shot(name) {
                const output = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!output) return
                window.contentItem.grabToImage(result => result.saveToFile(output + "/" + name + ".png"))
                wait(100)
            }
            function test_recording() {
                try {
                    Recording.observe = false
                    DesktopStatus.monitorServices = false
                    Config.update({appearance: {reduceMotion: false, personality: true}})
                    state("idle", 0)
                    pill.surface = "recording"
                    tryVerify(() => pill.surfaceItem !== null, 3000)
                    wait(800)
                    check(pill.surfaceItem.selectedPage === 1, "recording route chooses recording tab")
                    shot("recording-ready")
                    let primary = findChild(pill.surfaceItem, "recordingPrimary")
                    mouseClick(primary)
                    check(Recording.phase === "countdown" && Recording.countdown === 3, "explicit start starts cancellable countdown")
                    shot("countdown")
                    mouseClick(findChild(pill.surfaceItem, "focusTab"))
                    check(Recording.countdown === 0 && !Recording.engaged, "leaving tab cancels pending capture")
                    mouseClick(findChild(pill.surfaceItem, "recordingTab"))
                    wait(650)
                    mouseClick(primary)
                    check(Recording.countdown > 0, "countdown can restart")
                    pill.surface = "calendar"
                    check(Recording.countdown === 0, "another route cancels before outgoing surface teardown")
                    pill.surface = ""
                    check(Recording.countdown === 0, "closing panel cancels pending capture")
                    state("recording", 83)
                    wait(900)
                    check(Recording.engaged && Recording.active && Recording.timeText === "01:23", "confirmed recording drives pill")
                    shot("pill-recording")
                    state("paused", 83)
                    wait(350)
                    shot("pill-paused")
                    state("offline", 83, false)
                    check(Recording.uncertain && Recording.engaged && !Recording.active && !Recording.connected, "disconnect preserves unknown ongoing capture")
                    wait(600)
                    shot("pill-unknown")
                    state("recording", 86)
                    check(!Recording.uncertain && Recording.active, "reconnect reconciles state")
                    pill.surface = "recording"
                    tryVerify(() => pill.surfaceItem !== null, 3000)
                    wait(800)
                    shot("recording-active")
                    state("stopping", 86)
                    wait(200)
                    shot("recording-stopping")
                    check(saves === 0, "stopping does not claim file saved")
                    state("idle", 0, true, "/fixture/recording.mkv")
                    Recording.receive(JSON.stringify({type: "saved", outputPath: "/fixture/recording.mkv"}))
                    check(saves === 1, "confirmed saved event delivered once")
                    wait(500)
                    shot("recording-saved")
                    Config.update({appearance: {fontScale: 1.5}})
                    wait(900)
                    const help = findChild(pill.surfaceItem, "recordingHelp")
                    const helpPosition = help.mapToItem(pill, 0, 0)
                    check(helpPosition.y >= 0 && helpPosition.y + help.height <= pill.height - 12, "large text stays within material")
                    shot("recording-large-text")
                    Config.update({appearance: {reduceMotion: true}})
                    mouseClick(findChild(pill.surfaceItem, "focusTab"))
                    wait(30)
                    check(pill.surfaceItem.selectedPage === 0 && !Recording.engaged, "reduced tab switch resolves")
                    pill.surface = ""
                    state("offline", 0, false)
                    check(!Recording.start(), "disconnected cannot start")
                    console.log("PASS: recording tabs, countdown cancellation, confirmed pill state, pause, unknown disconnect, saved and reduced motion")
                    done = true
                } catch (error) { console.error("FAIL: recording integration " + error); Qt.exit(1) }
            }
        }
        Timer { interval: 150; running: checks.done; onTriggered: Qt.quit() }
    }
}
