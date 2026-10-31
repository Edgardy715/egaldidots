import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true; width: 900; height: 740
        color: Theme.background
        Pill { id: pill; x: (scene.width - width) / 2; y: 16; notificationsEnabled: false }
        Item { id: other; focus: false }
        TestCase {
            name: "LauncherEarlyFocus"
            when: scene.visible
            function search() { return pill.surfaceItem && findChild(pill.surfaceItem, "launcherSearch") }
            function type(text) { for (const letter of text) keyClick(letter) }
            function test_earlyTyping() {
                try {
                    Config.update({appearance: {reduceMotion: false, motionScale: 1}})
                    scene.requestActivate()
                    wait(80)
                    const start = Date.now()
                    pill.surface = "launcher"
                    tryVerify(() => search() !== null, 1500)
                    const loaded = Date.now()
                    tryCompare(search(), "activeFocus", true, 120)
                    type("firefox")
                    compare(pill.surfaceItem.query, "firefox", "early typing arrives without clicking the field")
                    console.log("LAUNCHER_READY_MS", Date.now() - start, "FOCUS_AFTER_LOAD_MS", Date.now() - loaded)
                    pill.launcherClosing = true
                    other.forceActiveFocus()
                    wait(180)
                    verify(!search().activeFocus, "closing launcher must not reclaim focus")
                    pill.launcherClosing = false
                    tryCompare(search(), "activeFocus", true, 120)
                    compare(pill.surfaceItem.query, "", "cancelled close starts a fresh search")
                    type("terminal")
                    compare(pill.surfaceItem.query, "terminal")
                    pill.surface = ""
                    other.forceActiveFocus()
                    wait(700)
                    verify(other.activeFocus, "unloaded launcher releases focus")
                    Config.update({appearance: {reduceMotion: true}})
                    pill.surface = "launcher"
                    tryVerify(() => search() !== null, 1500)
                    tryCompare(search(), "activeFocus", true, 120)
                    type("audio")
                    compare(pill.surfaceItem.query, "audio")
                    console.log("PASS: early typing, close cancellation, focus release and reduced motion")
                    Qt.quit()
                } catch (error) {
                    console.error("FAIL: launcher early focus", error)
                    Qt.exit(1)
                }
            }
        }
    }
    Timer { interval: 7000; running: true; onTriggered: { console.error("FAIL: launcher early focus timeout"); Qt.exit(1) } }
}
