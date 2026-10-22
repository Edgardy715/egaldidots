import QtQuick
import Quickshell
import Wpscan

ShellRoot {
    id: test
    readonly property string imageDir: Quickshell.env("ISLA_SCAN_DIR")
    readonly property string cacheDir: Quickshell.env("ISLA_SCAN_CACHE")
    readonly property int iterations: Number(Quickshell.env("ISLA_SCAN_ITERATIONS"))
    readonly property int expected: Number(Quickshell.env("ISLA_SCAN_EXPECTED"))
    property double scanStartedAt: 0
    property double batchStartedAt: 0
    property double lastHeartbeatAt: 0
    property double maxHeartbeatGapMs: 0
    property double batchMs: 0
    property int callbacks: 0
    property int itemCount: 0
    property var scanDoneSamplesMs: []
    property var startScanCallSamplesMs: []

    WallpaperScanner {
        id: scanner
        onScanDone: items => {
            test.callbacks++
            test.itemCount = items.length
            test.scanDoneSamplesMs.push(Date.now() - test.scanStartedAt)
            test.completeScan()
        }
    }

    function fail(message) {
        console.error("FAIL: " + message)
        Qt.exit(1)
    }
    function runOne() {
        test.scanStartedAt = Date.now()
        scanner.startScan(test.imageDir, test.cacheDir, 320, 180, 78)
        test.startScanCallSamplesMs.push(Date.now() - test.scanStartedAt)
    }
    function completeScan() {
        if (test.callbacks > test.iterations || test.itemCount !== test.expected)
            return test.fail("scan count/callback mismatch: " + test.callbacks + "/" + test.iterations
                + " callbacks, " + test.itemCount + "/" + test.expected + " items")
        if (test.callbacks === test.iterations) {
            test.batchMs = Date.now() - test.batchStartedAt
            report.start()
        } else nextScan.restart()
    }

    Timer {
        interval: 1
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now()
            if (test.lastHeartbeatAt > 0)
                test.maxHeartbeatGapMs = Math.max(test.maxHeartbeatGapMs, now - test.lastHeartbeatAt)
            test.lastHeartbeatAt = now
        }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            test.batchStartedAt = Date.now()
            test.lastHeartbeatAt = test.batchStartedAt
            test.runOne()
        }
    }
    Timer { id: nextScan; interval: 1; onTriggered: test.runOne() }
    Timer {
        id: report
        interval: 100
        onTriggered: {
            console.log("WALLPAPER_SCAN_RESULT " + JSON.stringify({
                items: test.itemCount,
                callbacks: test.callbacks,
                iterations: test.iterations,
                batchMs: test.batchMs,
                scanDoneSamplesMs: test.scanDoneSamplesMs,
                startScanCallSamplesMs: test.startScanCallSamplesMs,
                maxHeartbeatGapMs: test.maxHeartbeatGapMs
            }))
            Qt.quit()
        }
    }
    Timer { interval: 30000; running: true; onTriggered: test.fail("benchmark timed out") }
}
