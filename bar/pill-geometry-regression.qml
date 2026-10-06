import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    function equal(actual, expected, label) {
        if (Math.abs(actual - expected) > 0.001) {
            console.error("FAIL:", label, actual, "!=", expected)
            Qt.exit(1)
        }
    }
    PillGeometry {
        id: geometry
        s: 1
        restContentWidth: 120
        restHeight: 38
        surfaceSizes: ({auth: Qt.size(0, 0), launcher: Qt.size(680, 620), media: Qt.size(640, 300)})
        fallbackSurface: Qt.size(320, 300)
        mediaSurface: Qt.size(640, 300)
        marginMd: 10
        fontSizeBodyLg: 20
        fontSizeLabel: 12
        fontScale: 1
    }
    Timer {
        interval: 1
        running: true
        onTriggered: {
        test.equal(geometry.targetW, 156, "rest width")
        test.equal(geometry.targetH, 38, "rest height")
        test.equal(geometry.targetRadius, 19, "rest radius")

        geometry.surface = "auth"
        test.equal(geometry.targetW, 576, "auth width")
        test.equal(geometry.targetH, 82, "auth height")
        test.equal(geometry.targetRadius, 41, "auth radius")

        geometry.surface = "launcher"
        test.equal(geometry.launcherH, 158, "launcher unloaded")
        geometry.contentLoaded = true
        geometry.showCalculator = true
        test.equal(geometry.launcherH, 212, "launcher calculator")
        geometry.resultsVisible = true
        geometry.resultsCount = 3
        test.equal(geometry.launcherH, 429, "launcher results")
        geometry.resultsCount = 50
        test.equal(geometry.launcherH, 632, "launcher results cap")
        geometry.launcherClosing = true
        test.equal(geometry.targetH, 64, "launcher closing height")
        test.equal(geometry.targetRadius, 32, "launcher closing radius")
        geometry.launcherClosePhase = 2
        test.equal(geometry.targetW, 156, "launcher return width")
        test.equal(geometry.targetH, 38, "launcher return height")

        geometry.launcherClosing = false
        geometry.launcherClosePhase = 0
        geometry.surface = "media"
        geometry.albumDistinct = true
        test.equal(geometry.mediaH, 316, "media extra line")
        geometry.albumDistinct = false
        test.equal(geometry.mediaH, 300, "media base")
        geometry.albumDistinct = undefined
        geometry.album = "album"
        test.equal(geometry.mediaH, 316, "media album fallback")

        geometry.hasNotification = true
        geometry.notifAnimating = true
        geometry.notifState = "collapse-in"
        test.equal(geometry.targetW, 20.9, "notification overrides media width")
        test.equal(geometry.targetH, 20.9, "notification circle")
        geometry.notifState = "hold"
        test.equal(geometry.targetW, 380, "notification expanded width")
        test.equal(geometry.targetH, 72, "notification expanded height")
        geometry.surface = "auth"
        test.equal(geometry.targetW, 380, "notification overrides auth")
        geometry.notifState = "return"
        test.equal(geometry.targetW, 156, "notification return width")
        test.equal(geometry.targetRadius, 19, "notification return radius")

        geometry.hasNotification = false
        geometry.notifAnimating = false
        geometry.contentLoaded = false
        geometry.surface = "unknown"
        geometry.s = 2
        test.equal(geometry.targetW, 640, "scaled fallback width")
        test.equal(geometry.targetH, 600, "scaled fallback height")
        test.equal(geometry.targetRadius, 36, "scaled fallback radius")
        geometry.surface = "media"
        test.equal(geometry.targetH, 600, "scaled unloaded media")
        geometry.surface = ""
        test.equal(geometry.targetW, 192, "scaled rest padding")
        test.equal(geometry.targetH, 76, "scaled rest height")

        console.log("PASS: rest, auth, launcher, media and notification geometry")
        Qt.exit(0)
        }
    }
}
