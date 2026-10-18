import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    AudioController { id: audio; active: true }
    TestCase {
        name: "AudioControllerLifecycle"
        function until(predicate) {
            const deadline = Date.now() + 6000
            while (!predicate() && Date.now() < deadline) wait(20)
            if (!predicate()) { console.error("FAIL: audio controller", audio.error); Qt.exit(1); throw new Error(audio.error) }
        }
        function test_lifecycle() {
            until(() => audio.ready)
            verify(audio.outputs.length > 0)
            const output = audio.outputs.find(row => row.name === audio.defaultOutput) || audio.outputs[0]
            audio.meterSources = [output.monitorSource]
            until(() => Object.keys(audio.levels).includes(output.monitorSource))
            compare(audio.error, "")
            audio.active = false
            until(() => !audio.ready)
            compare(Object.keys(audio.levels).length, 0)
            wait(150)
            audio.active = true
            until(() => audio.ready)
            // A retained meter selection must also restart after reopening.
            until(() => Object.keys(audio.levels).includes(output.monitorSource))
            audio.active = false
            console.log("PASS: real audio controller snapshot, meter, close and retained reopen without audio mutations")
            Qt.quit()
        }
    }
}
