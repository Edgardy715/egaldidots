import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    BarLayoutTransition { id: transition }
    PillHeaderView { id: header; width: 600; height: 78; launcherHeaderVisible: true }
    TestCase {
        name: "BarLayoutTransition"
        when: Config.loaded
        function test_gatesAndRetarget() {
            Config.update({appearance: {reduceMotion: false}})
            transition.requestedCompact = true
            compare(transition.phase, 1)
            wait(90)
            verify(!transition.compact, "never reparent visible content")
            transition.exitReady = true
            tryCompare(transition, "phase", 2)
            verify(transition.compact)
            wait(100)
            verify(transition.active, "wait for real geometry, not a fixed timeout")
            transition.requestedCompact = false
            tryVerify(() => !transition.compact && transition.phase === 2)
            transition.settleReady = true
            tryCompare(transition, "phase", 0)
            transition.exitReady = false
            transition.requestedCompact = true
            compare(transition.phase, 1)
            transition.requestedCompact = false
            compare(transition.phase, 0)
            transition.requestedCompact = true
            Config.update({appearance: {reduceMotion: true}})
            verify(transition.compact && !transition.active)
            Config.update({appearance: {reduceMotion: false}})
            for (const surface of ["launcher", "auth", ""]) {
                header.surface = surface
                header.launcherHeaderVisible = surface === "launcher"
                header.layoutChanging = false
                tryVerify(() => header.restOpacity > 0.99)
                header.layoutChanging = true
                tryVerify(() => header.restOpacity < 0.01)
            }
            console.log("PASS: layout exit/settle gates, reversals, reduced motion and launcher/auth header withdrawal")
        }
    }
}
