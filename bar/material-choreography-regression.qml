import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1) }
    }
    MaterialChoreography {
        id: material
        shapeshiftDuration: 90
        pulseRiseDuration: 90
        pulseFallDuration: 90
        emphasizedDecelCurve: [0.05, 0.7, 0.1, 1, 1, 1]
    }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            test.check(material.epoch === 0 && material.sweep === -0.55 && material.pulse === 0,
                "initial state")
            material.awaken()
            test.check(material.epoch === 1, "first entrance")
            activeCheck.start()
        }
    }
    Timer {
        id: activeCheck
        interval: 45
        onTriggered: {
            test.check(material.pulse > 0 && material.sweep > -0.55, "animations progress")
            material.awaken()
            test.check(material.epoch === 2, "restart advances epoch")
            restartCheck.start()
        }
    }
    Timer {
        id: restartCheck
        interval: 45
        onTriggered: {
            test.check(material.pulse > 0 && material.sweep > -0.55, "restart progresses")
            material.reduceMotion = true
            test.check(material.pulse === 0 && material.sweep === -0.55, "reduce motion resets")
            material.awaken()
            test.check(material.epoch === 2, "reduced motion suppresses entrance")
            material.reduceMotion = false
            material.awaken()
            finished.start()
        }
    }
    Timer {
        id: finished
        interval: 250
        onTriggered: {
            test.check(material.epoch === 3 && Math.abs(material.sweep - 1.28) < 0.001
                && Math.abs(material.pulse) < 0.001, "animations finish")
            console.log("PASS: material entrance, restart, completion and reduced motion")
            Qt.exit(0)
        }
    }
}
