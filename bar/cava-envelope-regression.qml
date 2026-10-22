import QtQuick
import Quickshell
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property int updates: 0
    property int step: 0
    property int settledUpdates: 0
    readonly property string zero: Array(24).fill("0").join(" ")
    readonly property string tone: Array(24).fill("32768").join(" ")
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Window { visible: true; width: 100; height: 50 }
    Connections {
        target: Cava
        function onValuesChanged() { test.updates++ }
    }
    Component.onCompleted: {
        Cava.wanted = true
        Cava.parseFrame(zero)
        updates = 0
    }
    Timer {
        id: advance
        interval: 600; running: true; repeat: true
        onTriggered: {
            if (test.step === 0) {
                console.log("CAVA_SILENCE_UPDATES " + test.updates)
                if (Quickshell.env("ISLA_EXPECT_BASELINE") !== "1")
                    test.check(test.updates === 0, "initial silence must not publish frames")
                Cava.parseFrame(test.tone)
            } else if (test.step === 1) {
                test.check(Cava.values.every(v => v > 0 && v < 1), "tone attacks without overshoot")
                Cava.parseFrame(test.zero)
                advance.interval = 2600
            } else if (test.step === 2) {
                test.check(Cava.values.every(v => v === 0), "silence settles exactly")
                test.settledUpdates = test.updates
                Cava.parseFrame(test.zero)
                advance.interval = 600
            } else if (test.step === 3) {
                console.log("CAVA_SETTLED_UPDATES " + (test.updates - test.settledUpdates))
                if (Quickshell.env("ISLA_EXPECT_BASELINE") !== "1")
                    test.check(test.updates === test.settledUpdates, "settled silence stays asleep")
                Cava.parseFrame(test.tone)
            } else if (test.step === 4) {
                test.check(Cava.values.some(v => v > 0), "new audio resumes the envelope")
                Cava.reset()
                test.check(!Cava.hasFrame && Cava.values.every(v => v === 0), "reset clears envelope")
                Cava.wanted = false
                console.log(Quickshell.env("ISLA_EXPECT_BASELINE") === "1"
                    ? "PASS: baseline envelope activity measured; attack/release/resume/reset preserved"
                    : "PASS: silence suspends envelope, attack/release/resume/reset preserved")
                Qt.quit()
            }
            test.step++
        }
    }
    Timer { interval: 10000; running: true; onTriggered: { console.error("FAIL: envelope timeout"); Qt.exit(1) } }
}
