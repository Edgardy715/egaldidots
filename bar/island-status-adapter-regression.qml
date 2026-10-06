import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    property var received: []
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }

    IslandStatusAdapter {
        id: adapter
        observeServices: false
        s: 1.5
        onShowVolume: (progress, muted) => test.received.push(["volume", progress, muted])
        onShowMic: (progress, muted) => test.received.push(["mic", progress, muted])
        onShowBrightness: (progress) => test.received.push(["brightness", progress])
        onFallbackVolumeRequested: (scaleFactor) => test.received.push(["volume fallback", scaleFactor])
        onFallbackBrightnessRequested: (scaleFactor) => test.received.push(["brightness fallback", scaleFactor])
    }

    Component.onCompleted: {
        check(typeof adapter.capsLockOn === "boolean", "Caps Lock is exposed")
        adapter._queueOSD("volume", 0.2, false)
        adapter._queueOSD("volume", 0.7, true)
        volumeCheck.start()
    }
    Timer {
        id: volumeCheck
        interval: 45
        onTriggered: {
            test.check(test.received.length === 1 && test.received[0][0] === "volume"
                && test.received[0][1] === 0.7 && test.received[0][2], "volume debounce without fallback: " + JSON.stringify(test.received))
            adapter.fallbackVisible = true
            adapter._queueOSD("mic", 0.4, false)
            micCheck.start()
        }
    }
    Timer {
        id: micCheck
        interval: 45
        onTriggered: {
            test.check(test.received.length === 3 && test.received[1][0] === "mic"
                && test.received[1][1] === 0.4 && test.received[2][0] === "volume fallback"
                && test.received[2][1] === 1.5, "mic output and fallback scale")
            adapter._queueOSD("brightness", 0.8, false)
            brightnessCheck.start()
        }
    }
    Timer {
        id: brightnessCheck
        interval: 45
        onTriggered: {
            test.check(test.received.length === 5 && test.received[3][0] === "brightness"
                && test.received[3][1] === 0.8 && test.received[4][0] === "brightness fallback"
                && test.received[4][1] === 1.5, "brightness output and fallback scale")
            console.log("PASS: status adapter debounce, chip signals, fallback and Caps Lock API")
            Qt.exit(0)
        }
    }
}
