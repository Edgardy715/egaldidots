import QtQuick
import Quickshell
import "Singletons"
import "components"

// Deterministic elapsed-time checks, not a measurement of desktop frame rate.
ShellRoot {
    id: test
    settings.watchFiles: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1); throw new Error(message) }
    }
    Component {
        id: factory
        PillMorphMotion {
            manualStep: true
            restW: 150; coreH: 38
            targetW: 150; targetH: 38
        }
    }
    function opened() {
        const m = factory.createObject(test)
        m.surfaceName = "calendar"; m.surfaceOpen = true
        m.targetW = 660; m.targetH = 470
        return m
    }
    function advance(m, seconds, hz) {
        const count = Math.round(seconds * hz)
        for (let i = 0; i < count; ++i) m.step(seconds / count)
    }
    function near(a, b, message) {
        check(Math.abs(a.width - b.width) < 2 && Math.abs(a.height - b.height) < 2,
              message + " (" + a.width.toFixed(2) + "/" + b.width.toFixed(2) + ")")
    }
    Timer {
        interval: 100; running: Config.loaded
        onTriggered: {
            for (const scale of [0.25, 1, 2]) {
                Config.update({appearance: {motionScale: scale, reduceMotion: false}})
                const reference = opened()
                check(reference.timeScale === scale, "configured motion scale is applied")
                advance(reference, 0.3 * scale, 240 / scale)
                for (const hz of [144, 60, 30, 20, 10]) {
                    const m = opened()
                    advance(m, 0.3 * scale, hz / scale)
                    near(m, reference, "same elapsed time at " + hz + " Hz, scale " + scale)
                    m.destroy()
                }
                const stalled = opened()
                stalled.step(0.1 * scale)
                stalled.step(0.2 * scale)
                near(stalled, reference, "isolated late frames keep elapsed time")
                const w = stalled.width, v = stalled.velW
                stalled.surfaceName = "mixer"
                stalled.targetW = 560; stalled.targetH = 380
                check(stalled.width === w && stalled.velW === v, "retarget preserves state")
                stalled.step(0.1 * scale)
                check(isFinite(stalled.width) && isFinite(stalled.velW), "retarget after stall is finite")
                stalled.step(60)
                check(stalled.width === 560 && stalled.height === 380 && !stalled.integrating,
                      "long suspension settles with bounded work")
                stalled.surfaceOpen = false; stalled.surfaceName = ""
                stalled.targetW = 150; stalled.targetH = 38
                stalled.step(60)
                check(stalled.width === 150 && stalled.height === 38 && !stalled.springOn,
                      "close after suspension returns to rest")
                stalled.destroy(); reference.destroy()
            }
            const invalid = opened()
            for (const dt of [0, -1, NaN, Infinity]) invalid.step(dt)
            check(invalid.width === 150 && invalid.height === 38, "invalid intervals do not corrupt geometry")
            invalid.reduceMotion = true
            check(invalid.width === 660 && invalid.height === 470 && invalid.velW === 0,
                  "reduced motion resolves the current destination")
            invalid.destroy()
            console.log("PASS: elapsed time, late frames, speed scales, interruption, suspension and reduced motion")
            Qt.quit()
        }
    }
}
