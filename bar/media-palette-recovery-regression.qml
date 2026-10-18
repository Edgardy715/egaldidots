import QtQuick
import QtTest
import Quickshell
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 40; height: 40
        TestCase {
            id: checks
            name: "PaletteRecovery"
            when: scene.visible
            property bool finished: false
            function test_recovery() {
                try {
                    const base = Quickshell.env("ISLA_PALETTE_TEST_BASE")
                    MediaPalette.source = base + "/slow.svg"
                    tryCompare(MediaPalette, "loadingSource", MediaPalette.source)
                    wait(250)
                    const switched = Date.now()
                    MediaPalette.source = base + "/blue.svg"
                    tryVerify(() => MediaPalette.extracted !== null, 1800)
                    verify(Date.now() - switched < 1800, "new track does not wait for slow artwork")
                    compare(MediaPalette.loadingSource, base + "/blue.svg")
                    const previous = String(MediaPalette.extracted)
                    MediaPalette.source = base + "/flaky.svg"
                    tryVerify(() => MediaPalette.retryCount === 1, 2000)
                    tryVerify(() => MediaPalette.extracted !== null && String(MediaPalette.extracted) !== previous, 3000)
                    compare(MediaPalette.retryCount, 1, "temporary failure recovers on bounded retry")
                    MediaPalette.requestTimeout = 200
                    MediaPalette.source = base + "/timeout.svg"
                    tryVerify(() => MediaPalette.retryCount === 1, 2000)
                    tryVerify(() => MediaPalette.extracted !== null, 2500)
                    MediaPalette.requestTimeout = 12000
                    MediaPalette.source = base + "/missing.svg"
                    tryCompare(MediaPalette, "retryCount", 2, 4500)
                    wait(1900)
                    compare(MediaPalette.extracted, null)
                    compare(MediaPalette.handledSource, base + "/missing.svg")
                    MediaPalette.source = ""
                    compare(MediaPalette.target, Theme.accent)
                    console.log("PASS: palette cancels obsolete work, retries transient failure and bounds persistent failure")
                    finished = true
                } catch(error) { console.error("FAIL: palette recovery",error); Qt.exit(1) }
            }
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 15000; running: true; onTriggered: Qt.exit(1) }
}
