import QtQuick
import Quickshell
import "lockscreen"

ShellRoot {
    id: test
    settings.watchFiles: false
    property int step: 0
    property var intervals: []
    property double previousFrame: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Window {
        visible: true
        width: 1440; height: 900
        title: "Isla · Fluidez del bloqueo"
        LockSurface {
            id: surface
            anchors.fill: parent
            username: "Vista previa"
            avatarSource: ""
            wallpaper: Quickshell.env("ISLA_LOCK_WALLPAPER")
            secured: true
            preview: true
            onUnlockRequested: test.check(false, "performance fixture must not authenticate")
        }
    }
    FrameAnimation {
        running: surface.presentation > 0 && surface.presentation < 1
        onRunningChanged: test.previousFrame = 0
        onTriggered: {
            const now = Date.now()
            if (test.previousFrame) test.intervals.push(now - test.previousFrame)
            test.previousFrame = now
            test.check(Number.isFinite(surface.presentation), "finite presentation")
        }
    }
    Timer {
        interval: 1100
        running: true; repeat: true
        onTriggered: {
            if (test.step > 0)
                test.check(Math.abs(surface.presentation - (surface.authActive ? 1 : 0)) < 0.01, "transition settles")
            if (test.step++ < 12) {
                surface.authActive = !surface.authActive
                return
            }
            test.check(test.intervals.length > 12, "animated frames observed")
            test.intervals.sort((a, b) => a - b)
            const n = test.intervals.length
            console.log("LOCK_FRAME_INTERVALS " + JSON.stringify({samples: n, medianMs: test.intervals[Math.floor(n / 2)], p95Ms: test.intervals[Math.floor(n * 0.95)], maxMs: test.intervals[n - 1]}))
            console.log("PASS: repeated lock transitions settle without authentication")
            Qt.quit()
        }
    }
}
