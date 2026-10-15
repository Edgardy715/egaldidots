import QtQuick
import Quickshell
import Wpscan

ShellRoot {
    readonly property string imageDir: Quickshell.env("ISLA_SCAN_DIR")
    readonly property string cacheDir: Quickshell.env("ISLA_SCAN_CACHE")
    readonly property bool expectReady: Quickshell.env("ISLA_SCAN_READY") === "1"

    WallpaperScanner {
        id: scanner
        onScanDone: items => {
            if (items.length !== 1 || items[0].thumbReady !== expectReady) {
                console.error("FAIL: scanner readiness", JSON.stringify(items), expectReady)
                Qt.exit(1)
                return
            }
            if (expectReady) {
                console.log("PASS: current thumbnail reused")
                doneTimer.start()
            } else {
                scanner.generateThumb(items[0].path, items[0].thumb, 320, 180, 78)
            }
        }
        onThumbReady: (source, cache, available, updated, error) => {
            if (!available || !updated) {
                console.error("FAIL: thumbnail regeneration", error)
                Qt.exit(1)
                return
            }
            console.log("PASS: thumbnail regenerated")
            Qt.quit()
        }
        Component.onCompleted: startScan(imageDir, cacheDir, 320, 180, 78)
    }
    Timer { id: doneTimer; interval: 20; onTriggered: Qt.quit() }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: scanner timeout"); Qt.exit(1) } }
}
