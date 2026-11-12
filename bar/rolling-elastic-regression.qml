import QtQuick
import "components/RubberBand.js" as RubberBand
import QtTest
import Quickshell
import "components"
import "Singletons"
import "components/audio"

// RollingNumber (odómetro de cifras) y banda elástica del Slider.
ShellRoot {
    id: test
    property int step: 0
    property var reel: null
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) { const match = find(child, name); if (match) return match }
        return null
    }
    function firstReel(item) {
        if (item.hasOwnProperty("numericDirection")) return item
        for (const child of item.children) { const r = firstReel(child); if (r) return r }
        return null
    }
    Window {
        id: win
        visible: true; width: 320; height: 120; color: Theme.background
        RollingNumber { id: number; value: 40; suffix: "%"; font.pixelSize: 15; x: 10; y: 10 }
        Slider { id: slider; x: 40; y: 60; width: 200; s: 1; value: 0.5 }
        AudioFader { id: fader; x: 40; y: 84; width: 200; s: 1; volume: 0.5 }
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            switch (test.step++) {
            case 0:
                test.reel = test.firstReel(number)
                test.check(test.reel && test.reel.shown === "40" && !number.rolling, "initial value settled without a roll")
                test.check(number.width > 0 && number.baselineOffset > 0, "row exposes size and baseline")
                number.value = 45
                break
            case 1:
                test.check(number.rolling && test.reel.rollDirection === 1, "counting up rolls from above")
                number.value = 50   // queued behind the running roll
                break
            case 14:
                test.check(test.reel.shown === "50" && !number.rolling, "queued value settles (burst roll)")
                number.value = 5
                break
            case 15:
                test.check(number.rolling && test.reel.rollDirection === -1, "counting down rolls from below")
                break
            case 30:
                test.check(test.reel.shown === "5" && !number.rolling, "shorter value settles")
                number.immediate = true
                number.value = 77
                break
            case 31:
                test.check(test.reel.shown === "77" && !number.rolling, "immediate (direct manipulation) shows value 1:1")
                number.immediate = false
                // Overdrag past the right end: value clamps, track stretches with resistance.
                mouseMove(slider, 100, 10); mousePress(slider, 100, 10)
                mouseMove(slider, 240, 10); mouseMove(slider, 400, 10)
                break
            case 32:
                test.check(slider.dragValue === 1, "value clamps at the end")
                test.check(slider.overdrag > 0 && slider.overdrag < slider.maxOverdrag, "track stretches but never past maxOverdrag: " + slider.overdrag)
                mouseRelease(slider, 400, 10)
                break
            case 33:
                test.check(!slider.overdragLive, "release hands the stretch back to the spring")
                break
            case 60:
                test.check(Math.abs(slider.overdrag) < 0.2, "stretch returns to rest: " + slider.overdrag)
                mousePress(slider, 100, 10); mouseMove(slider, 20, 10); mouseMove(slider, -200, 10)
                break
            case 61:
                test.check(slider.dragValue === 0 && slider.overdrag < 0, "left overdrag stretches toward the pointer")
                mouseRelease(slider, -200, 10)
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary reduced motion")
                break
            case 62:
                mousePress(slider, 100, 10); mouseMove(slider, 400, 10)
                test.check(slider.overdrag === 0, "reduced motion: no stretch")
                mouseRelease(slider, 400, 10)
                number.value = 12
                break
            case 63:
                test.check(test.reel.shown === "12" && !number.rolling, "reduced motion: no roll")
                Config.update({appearance: {reduceMotion: false}})
                break
            case 64:
                mousePress(fader, 100, 16); mouseMove(fader, 260, 16); mouseMove(fader, 420, 16)
                break
            case 65:
                test.check(fader.overdrag > 0 && fader.overdrag < fader.maxOverdrag, "mixer fader stretches past its end: " + fader.overdrag)
                mouseRelease(fader, 420, 16)
                break
            case 95:
                test.check(Math.abs(fader.overdrag) < 0.2 && !fader.overdragLive, "mixer fader springs back: " + fader.overdrag)
                console.log("PASS: rolling number direction/burst/immediate/reduced and slider + mixer fader rubber band (clamp, bound, spring back, left, reduced)")
                Qt.quit()
            }
        }
    }
    TestCase { id: tc; when: false }
    function mouseMove(i, x, y) { tc.mouseMove(i, x, y) }
    function mousePress(i, x, y) { tc.mousePress(i, x, y) }
    function mouseRelease(i, x, y) { tc.mouseRelease(i, x, y) }
    Component.onCompleted: {
        const asymptote = RubberBand.rubberBand(1e12, 40, 0.55)
        const small = RubberBand.rubberBand(0.001, 40, 0.55)
        check(asymptote > 39.99 && asymptote < 40, "rubberBand asymptote: " + asymptote)
        check(Math.abs(small - 0.00055) < 1e-8, "rubberBand small displacement: " + small)
        check(Math.abs(RubberBand.rubberBand(-10, 40, 0.55) + RubberBand.rubberBand(10, 40, 0.55)) < 1e-10, "rubberBand symmetry")
        console.log("PASS: rubberBand asymptote, small displacement, symmetry")
    }
}
