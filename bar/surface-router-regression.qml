import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    property int authCancels: 0
    function check(value, message) {
        if (!value) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    SurfaceRouter {
        id: router
        focusedMonitorName: "DP-1"
        resultsDuration: 30
        morphDuration: 100
        onAuthCloseRequested: test.authCancels++
    }
    Component.onCompleted: {
        router.toggleSurface("", "calendar")
        check(router.openMon === "DP-1" && router.openSurface === "calendar", "focused monitor")
        router.toggleSurface("DP-1", "calendar")
        check(router.openSurface === "", "same surface closes")
        router.toggleSurface("DP-2", "wallpaper")
        check(router.mediaDockPendingMon === "DP-2" && router.openSurface === "", "wait for dock")
        router.finishMediaDock("DP-1")
        check(router.openSurface === "", "wrong monitor completion ignored")
        router.toggleSurface("DP-2", "wallpaper")
        router.finishMediaDock("DP-2")
        check(router.openSurface === "", "cancel pending dock")
        router.toggleSurface("DP-1", "overview")
        router.present("DP-2", "auth")
        router.finishMediaDock("DP-1")
        check(router.openSurface === "auth" && router.openMon === "DP-2", "auth supersedes pending dock")
        router.close()
        check(authCancels === 1 && router.openSurface === "", "auth cancellation delegated")
        router.toggleSurface("DP-1", "launcher")
        router.finishMediaDock("DP-1")
        router.close()
        check(router.launcherClosePhase === 1 && router.openSurface === "launcher", "first close phase")
        phaseTwo.start()
    }
    Timer {
        id: phaseTwo; interval: 65
        onTriggered: {
            test.check(router.launcherClosePhase === 2, "second close phase")
            router.toggleSurface("DP-1", "launcher")
            test.check(router.launcherClosePhase === 0 && router.openSurface === "launcher", "reopen interrupted close")
            reopen.start()
        }
    }
    Timer {
        id: reopen; interval: 150
        onTriggered: {
            test.check(router.openSurface === "launcher", "old timer cannot close reopened launcher")
            router.close()
            router.toggleSurface("DP-2", "calendar")
            replaced.start()
        }
    }
    Timer {
        id: replaced; interval: 170
        onTriggered: {
            test.check(router.openSurface === "calendar" && router.openMon === "DP-2", "retarget cancels timers")
            router.toggleSurface("DP-1", "launcher")
            router.finishMediaDock("DP-1")
            router.reduceMotion = true
            router.close()
            test.check(router.openSurface === "" && router.launcherClosePhase === 0, "reduced motion closes directly")
            router.reduceMotion = false
            router.toggleSurface("DP-1", "launcher")
            router.finishMediaDock("DP-1")
            router.close()
            finished.start()
        }
    }
    Timer {
        id: finished; interval: 170
        onTriggered: {
            test.check(router.openSurface === "" && router.openMon === "" && router.launcherClosePhase === 0, "complete two-phase close")
            router.focusedMonitorName = ""
            router.toggleSurface("", "calendar")
            test.check(router.openSurface === "" && router.pendingFocusSurface === "calendar", "startup request waits for monitor")
            router.toggleSurface("", "launcher")
            router.focusedMonitorName = "DP-1"
            test.check(router.mediaDockPendingMon === "DP-1" && router.mediaDockPendingSurface === "launcher", "latest startup request resumes docking")
            router.finishMediaDock("DP-1")
            test.check(router.openSurface === "launcher", "first launcher request survives monitor startup")
            router.close()
            router.reduceMotion = true
            router.close()
            router.focusedMonitorName = ""
            router.toggleSurface("", "calendar")
            router.toggleSurface("", "calendar")
            router.focusedMonitorName = "DP-1"
            test.check(router.openSurface === "" && router.pendingFocusSurface === "", "repeated startup toggle cancels")
            router.focusedMonitorName = ""
            router.toggleSurface("", "calendar")
            router.close()
            router.focusedMonitorName = "DP-1"
            test.check(router.openSurface === "", "hide cancels startup request")
            console.log("PASS: routing, dock cancellation, auth priority, two-phase close, interruption and reduced motion")
            Qt.quit()
        }
    }
    Timer { interval: 3000; running: true; onTriggered: { console.error("FAIL: routing timeout"); Qt.exit(1) } }
}
