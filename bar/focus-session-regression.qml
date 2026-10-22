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
        width: 420
        height: 420
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        FocusTimerView {
            id: view
            anchors.fill: parent
            anchors.margins: 24
            session: FocusSession
            open: true
        }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property real nowMs: 100000
            property int completions: 0
            property int rejections: 0
            property bool done: false
            Connections {
                target: FocusSession
                function onFinished() { checks.completions++ }
                function onRejected(reason) { checks.rejections++ }
            }
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function test_focus() {
                try {
                    FocusSession.clock = () => checks.nowMs
                    const output = Quickshell.env("ISLA_TEST_OUTPUT")
                    if (output) {
                        wait(100)
                        window.contentItem.grabToImage(result => result.saveToFile(output + "/focus-initial.png"))
                        wait(100)
                    }
                    for (const invalid of [0, 181, -1, 1.5, NaN, Infinity, "25", null, undefined])
                        assert(!FocusSession.start(invalid), "reject invalid duration " + invalid)
                    assert(rejections === 9 && !FocusSession.active, "validation leaves idle state")
                    assert(FocusSession.start(1) && FocusSession.running && FocusSession.remainingSeconds === 60, "start")
                    assert(!FocusSession.start(181) && FocusSession.remainingSeconds === 60, "invalid start preserves active session")
                    nowMs += 10500
                    FocusSession.refresh()
                    assert(FocusSession.remainingSeconds === 50 && Math.abs(FocusSession.progress - 0.175) < 0.0001, "deadline, ceil and progress")
                    assert(FocusSession.pause() && FocusSession.paused && !FocusSession.running, "pause")
                    nowMs += 300000
                    FocusSession.refresh()
                    assert(FocusSession.remainingSeconds === 50, "paused time preserved")
                    assert(FocusSession.resume() && FocusSession.running, "resume")
                    nowMs += 49499
                    FocusSession.refresh()
                    assert(FocusSession.remainingSeconds === 1 && completions === 0, "resume preserves milliseconds")
                    nowMs++
                    FocusSession.refresh()
                    assert(!FocusSession.active && FocusSession.remainingSeconds === 0 && FocusSession.progress === 1 && completions === 1, "expiration")
                    FocusSession.refresh(); FocusSession.pause(); FocusSession.resume()
                    assert(completions === 1, "completion delivered once")
                    view.selectedMinutes = 45
                    assert(!view.completed && view.timeText === "45:00", "choosing next duration leaves completed presentation")
                    FocusSession.start(180)
                    nowMs += 180 * 60000 + 5000
                    assert(!FocusSession.pause() && completions === 2 && !FocusSession.active, "pause after suspend expires deadline")
                    FocusSession.start(25)
                    assert(FocusSession.cancel() && !FocusSession.active && FocusSession.durationSeconds === 0 && FocusSession.progress === 0, "cancel resets")
                    nowMs += 180 * 60000
                    FocusSession.refresh()
                    assert(completions === 2, "cancel does not finish later")
                    assert(!FocusSession.pause() && !FocusSession.resume() && !FocusSession.cancel(), "idle actions are harmless")
                    const primary = findChild(view, "focusPrimary")
                    const cancel = findChild(view, "focusCancel")
                    primary.forceActiveFocus()
                    keyClick(Qt.Key_Space)
                    assert(FocusSession.running && FocusSession.durationSeconds === 1500, "keyboard starts")
                    keyClick(Qt.Key_Space)
                    assert(FocusSession.paused, "keyboard pauses")
                    keyClick(Qt.Key_Space)
                    assert(FocusSession.running, "keyboard resumes")
                    keyClick(Qt.Key_Tab)
                    assert(cancel.activeFocus, "Tab reaches cancel")
                    keyClick(Qt.Key_Space)
                    assert(!FocusSession.active, "keyboard cancels")
                    Config.update({appearance:{reduceMotion:true}})
                    primary.forceActiveFocus(); keyClick(Qt.Key_Space)
                    assert(FocusSession.running, "reduced motion keyboard starts")
                    FocusSession.cancel()
                    const input = findChild(view, "focusMinutes")
                    input.text = ""
                    assert(!primary.enabled, "empty duration disables start")
                    input.text = "181"
                    assert(!primary.enabled, "out of range duration disables start")
                    input.text = "1"
                    assert(primary.enabled, "valid custom duration enables start")
                    primary.forceActiveFocus(); keyClick(Qt.Key_Space)
                    assert(FocusSession.durationSeconds === 60, "custom duration is honored")
                    FocusSession.cancel()
                    console.log("PASS: focus validation, deadlines, pause/resume milliseconds, suspend, finish once, cancel, custom minutes, keyboard and reduced motion")
                } catch (error) {
                    console.error("FAIL: focus", error.message)
                }
                done = true
            }
        }
        Timer { interval: 100; running: checks.done; onTriggered: Qt.quit() }
    }
}
