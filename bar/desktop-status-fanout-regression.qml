import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    property var firstEvents: []
    property var secondEvents: []
    property int isolatedEvents: 0

    IslandStatusAdapter {
        id: firstAdapter
        s: 1.25
        fallbackVisible: true
        onShowVolume: (progress, muted) => test.firstEvents.push(["volume", progress, muted])
        onShowBattery: (percent, status) => test.firstEvents.push(["battery", percent, status])
        onFallbackVolumeRequested: (scale) => test.firstEvents.push(["fallback", scale])
    }
    IslandStatusAdapter {
        id: secondAdapter
        s: 2
        onShowVolume: (progress, muted) => test.secondEvents.push(["volume", progress, muted])
        onShowBattery: (percent, status) => test.secondEvents.push(["battery", percent, status])
        onFallbackVolumeRequested: (scale) => test.secondEvents.push(["fallback", scale])
    }
    IslandStatusAdapter {
        id: isolatedAdapter
        observeServices: false
        onShowVolume: test.isolatedEvents++
        onShowBattery: test.isolatedEvents++
    }

    Component.onCompleted: {
        if (isolatedAdapter.capsLockOn !== false) fail("isolated Caps Lock default")
        DesktopStatus.monitorServices = false
        settle.start()
    }
    function fail(message) {
        console.error("FAIL: " + message)
        Qt.exit(1)
    }
    Timer {
        id: settle
        interval: 60
        onTriggered: {
            test.firstEvents = []
            test.secondEvents = []
            DesktopStatus.volumeOSD(0.2, false)
            DesktopStatus.volumeOSD(0.7, true)
            volumeCheck.start()
        }
    }
    Timer {
        id: volumeCheck
        interval: 45
        onTriggered: {
            if (test.firstEvents.length !== 2 || test.firstEvents[0][0] !== "volume"
                    || test.firstEvents[0][1] !== 0.7 || test.firstEvents[0][2] !== true
                    || test.firstEvents[1][0] !== "fallback" || test.firstEvents[1][1] !== 1.25)
                return test.fail("first adapter debounce/fallback: " + JSON.stringify(test.firstEvents))
            if (test.secondEvents.length !== 1 || test.secondEvents[0][0] !== "volume"
                    || test.secondEvents[0][1] !== 0.7 || test.secondEvents[0][2] !== true)
                return test.fail("second adapter fanout: " + JSON.stringify(test.secondEvents))
            DesktopStatus.batteryOSD(74, "charging")
            batteryCheck.start()
        }
    }
    Timer {
        id: batteryCheck
        interval: 20
        onTriggered: {
            if (test.firstEvents.length !== 3 || test.firstEvents[2][0] !== "battery"
                    || test.firstEvents[2][1] !== 74 || test.firstEvents[2][2] !== "charging"
                    || test.secondEvents.length !== 2 || test.secondEvents[1][0] !== "battery")
                return test.fail("battery event fanout")
            DesktopStatus._capsLockOn = true
            if (!firstAdapter.capsLockOn || !secondAdapter.capsLockOn
                    || isolatedAdapter.capsLockOn || test.isolatedEvents !== 0)
                return test.fail("shared Caps Lock and disabled adapter isolation")
            console.log("PASS: shared status events fan out to two adapters; per-adapter debounce, fallback scale and isolated Caps Lock")
            Qt.exit(0)
        }
    }
}
