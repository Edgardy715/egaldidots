import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 440
        height: 438
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        RecordingView {
            id: view
            anchors.fill: parent
            anchors.margins: 24
            open: true
            onStartRequested: checks.starts++
            onStopRequested: checks.stops++
            onPauseRequested: checks.pauses++
            onResumeRequested: checks.resumes++
            onRefreshRequested: checks.refreshes++
            onSystemAudioToggled: { checks.audioToggles++; systemAudio = !systemAudio }
            onMicrophoneAudioToggled: { checks.audioToggles++; microphoneAudio = !microphoneAudio }
            onOpenOutputRequested: checks.outputs++
        }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property int starts: 0
            property int stops: 0
            property int pauses: 0
            property int resumes: 0
            property int refreshes: 0
            property int audioToggles: 0
            property int outputs: 0
            property bool done: false
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function capture(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                wait(Motion.standardSmall + Motion.press + 30)
                window.contentItem.grabToImage(result => result.saveToFile(directory + "/recording-" + name + ".png"))
                wait(80)
            }
            function test_recordingView() {
                try {
                    const primary = findChild(view, "recordingPrimary")
                    const shape = findChild(view, "recordingPrimaryShape")
                    const pause = findChild(view, "recordingPause")
                    const refresh = findChild(view, "recordingRefresh")
                    const output = findChild(view, "recordingOutput")
                    const help = findChild(view, "recordingHelp")
                    wait(100)
                    assert(!primary.visible && !primary.enabled && help.text.includes("gpu-screen-recorder"), "offline setup is actionable")
                    mouseClick(refresh)
                    assert(refreshes === 1, "offline retry action")
                    capture("offline")
                    view.connected = true; view.setupRequired = true; view.phase = "idle"
                    assert(!primary.enabled, "setup required cannot start")
                    view.setupRequired = false
                    wait(450)
                    capture("idle")
                    assert(primary.enabled && primary.visible, "ready can start")
                    mouseClick(findChild(view, "recordingSystemAudio"))
                    mouseClick(findChild(view, "recordingMicrophone"))
                    assert(audioToggles === 2 && !view.systemAudio && view.microphoneAudio, "audio choices are explicit")
                    primary.forceActiveFocus(); keyClick(Qt.Key_Space)
                    assert(starts === 1 && view.phase === "idle", "keyboard start requests only, never fabricates recording")
                    view.phase = "countdown"; view.countdown = 2
                    assert(findChild(view, "recordingTime").text === "2", "countdown comes from backend")
                    mouseClick(primary)
                    assert(stops === 1, "countdown cancel requests stop")
                    view.phase = "starting"
                    assert(!primary.enabled && help.text.includes("selector"), "starting waits for picker")
                    mouseClick(primary)
                    assert(starts === 1, "busy action disabled")
                    view.phase = "recording"; view.elapsedSeconds = 3661
                    wait(450)
                    tryVerify(() => Math.abs(shape.radius - 18) < 0.05, 1500)
                    assert(view.timeText === "01:01:01", "confirmed record state and hour duration")
                    capture("active")
                    view.requestBusy = true
                    assert(!primary.enabled && !pause.enabled, "pending request disables controls without changing confirmed phase")
                    mouseClick(primary); mouseClick(pause)
                    assert(pauses === 0 && stops === 1, "busy confirmed state ignores duplicate requests")
                    view.requestBusy = false; view.pauseSupported = false
                    assert(primary.enabled && !pause.enabled, "unsupported pause keeps stop available")
                    view.pauseSupported = true; view.error = "El codificador rechazó la pausa."
                    assert(help.text === view.error && primary.enabled && view.phase === "recording", "encoder rejection preserves active stop and shows error")
                    view.error = ""
                    mouseClick(pause)
                    assert(pauses === 1 && view.phase === "recording", "pause waits for backend")
                    view.phase = "paused"
                    pause.forceActiveFocus(); keyClick(Qt.Key_Space)
                    assert(resumes === 1 && view.phase === "paused", "keyboard resume requests only")
                    keyClick(Qt.Key_Tab)
                    assert(primary.activeFocus, "Tab returns from pause to stop")
                    keyClick(Qt.Key_Space)
                    assert(stops === 2, "keyboard stop")
                    view.phase = "stopping"; view.outputPath = "/tmp/unconfirmed.mkv"
                    assert(!output.visible && !primary.enabled, "stopping never announces saved output")
                    view.phase = "error"; view.error = "El grabador no confirmó el archivo."
                    assert(!output.visible && help.text === view.error, "error shows recovery without saved claim")
                    capture("error")
                    view.phase = "idle"; view.error = ""; view.elapsedSeconds = 0
                    assert(output.visible, "confirmed stopped output available")
                    output.forceActiveFocus(); keyClick(Qt.Key_Space)
                    assert(outputs === 1, "output keyboard action")
                    view.outputPath = ""
                    wait(450)
                    view.phase = "recording"
                    wait(60)
                    assert(shape.radius > 18 && shape.radius < 26, "morph has an intermediate geometry")
                    view.open = false
                    wait(1)
                    assert(shape.radius === 18 && !view.motionAllowed && !primary.enabled && !pause.enabled, "hidden resolves shape and disables controls")
                    Config.update({appearance:{reduceMotion:true}})
                    view.open = true; view.phase = "idle"
                    wait(30)
                    assert(shape.radius === 26 && shape.width === primary.width, "reduced motion resolves idle shape")
                    view.phase = "recording"
                    wait(30)
                    assert(shape.radius === 18 && shape.width === primary.width, "reduced motion resolves recording shape")
                    capture("reduced")
                    console.log("PASS: recording view offline/setup, countdown cancel, confirmed states, errors/output, busy/capabilities, mouse, keyboard, morph, hidden and reduced motion")
                } catch (error) {
                    console.error("FAIL: recording view", error.message)
                    Qt.exit(1)
                }
                done = true
            }
        }
        Timer { interval: 120; running: checks.done; onTriggered: Qt.quit() }
    }
}
