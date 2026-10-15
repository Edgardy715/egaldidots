import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    WallpaperController { id: recovery; onSelectionRequested: index => recovery.selectedIndex = index }
    Window {
        id: window
        visible: true; width: 10; height: 10
        TestCase {
            id: checks
            when: window.visible
            name: "WallpaperApplyProtocol"
            property int handoffs: 0
            property int completions: 0
            property bool finished: false
            Connections {
                target: Wallpapers
                function onTransitionHandoff() { checks.handoffs++ }
                function onApplyFinished(path, success) { checks.completions++ }
            }
            function check(value, message) { if (!value) { console.error("FAIL: wallpaper protocol", message); Qt.exit(1); throw new Error(message) } }
            function waitFor(predicate) {
                const deadline = Date.now() + 4000
                while (!predicate() && Date.now() < deadline) wait(15)
                check(predicate(), "process state timed out")
            }
            function test_protocol() {
                Config.update({paths:{wallpaperApplyScript:Quickshell.env("ISLA_TEST_APPLY_SCRIPT")}})
                check(Wallpapers.setWallpaper("/tmp/isla-success.png"), "first request accepted")
                check(Wallpapers.applyPhase === "preparing", "preparation precedes handoff")
                check(!Wallpapers.setWallpaper("/tmp/isla-overlap.png"), "overlapping apply rejected")
                waitFor(() => completions === 1)
                check(handoffs === 1 && Wallpapers.applyPhase === "done", "framed handoff and successful completion")
                check(Wallpapers.current === "/tmp/isla-success.png", "successful wallpaper remembered")
                check(Wallpapers.setWallpaper("/tmp/isla-fail.png"), "next request accepted")
                waitFor(() => completions === 2)
                check(handoffs === 2 && Wallpapers.applyPhase === "error", "partial apply never confirms success")
                check(Wallpapers.current === "/tmp/isla-fail.png" && Wallpapers.applyError.length > 0, "partial apply retains actual wallpaper and reports colors error")
                Wallpapers.list = ["/tmp/isla-success.png", "/tmp/isla-fail.png"].map(path => ({
                    path:path,baseName:path,thumb:"/tmp/unused.jpg",thumbSource:"",thumbReady:true,cacheRevision:0}))
                recovery.open = true
                wait(30)
                check(recovery.feedback === "error" && recovery.wallpaperModel.get(recovery.selectedIndex).path === "/tmp/isla-fail.png", "reopen retains failed selection and retry feedback")
                waitFor(() => Wallpapers.applyPhase === "")
                console.log("PASS: wallpaper handoff protocol, busy guard, success, partial failure and feedback release")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
}
