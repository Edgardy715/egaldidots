import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    property int advances: 0
    property var visited: ({})
    property var first: ({ summary: "first" })
    property var second: ({ summary: "second" })
    function check(value, message) {
        if (!value) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    NotificationChoreography {
        id: flow
        collapseDuration: 20
        expandDuration: 20
        holdDuration: 25
        restoreDuration: 40
        surfaceOpen: true
        onNotifStateChanged: test.visited[notifState] = true
        onAdvanceRequested: {
            test.advances++
            popup = test.advances === 1 ? test.second : null
        }
    }
    Component.onCompleted: {
        flow.popup = first
        check(flow.notifState === "collapse-in" && flow.surfaceNotifSuspended && flow.surfaceReveal === 0, "suspend before collapse")
    }
    Timer {
        interval: 320; running: true
        onTriggered: {
            test.check(test.advances === 2 && flow.notifState === "idle", "queued notifications complete")
            test.check(!flow.surfaceNotifSuspended && flow.surfaceReveal === 1, "surface restored")
            for (const phase of ["collapse-in", "expand", "hold", "collapse-out", "return", "idle"])
                test.check(test.visited[phase], "visited " + phase)
            flow.popup = test.first
            flow.popup = null
            test.check(flow.notifState === "collapse-out", "expiry during entrance")
            flow.surfaceOpen = false
            test.check(!flow.surfaceNotifSuspended && flow.surfaceReveal === 1, "closing surface clears suspension")
            expired.start()
        }
    }
    Timer {
        id: expired; interval: 120
        onTriggered: {
            test.check(flow.notifState === "idle" && !flow.activeNotif, "early expiry finishes")
            flow.popup = test.first
            flow.surfaceOpen = true
            test.check(flow.surfaceNotifSuspended && flow.surfaceReveal === 0, "surface opened during notification stays hidden")
            restored.start()
        }
    }
    Timer {
        id: restored; interval: 180
        onTriggered: {
            test.check(flow.notifState === "idle" && !flow.surfaceNotifSuspended, "late-opened surface restored")
            console.log("PASS: notification phases, queue, early expiry, surface close and late-open restoration")
            Qt.quit()
        }
    }
    Timer { interval: 2000; running: true; onTriggered: { console.error("FAIL: notification timeout"); Qt.exit(1) } }
}
