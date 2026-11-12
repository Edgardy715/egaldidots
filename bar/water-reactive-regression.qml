import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "body"
import "body/WaterReactive.js" as WR

// Material vivo: cover tint, adjustment ripple and bass brightness of the water body.
// Numeric rules run everywhere; the live branch needs a real renderer (RHI), software
// only proves the fallbacks. Offscreen is not visual QA.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        x: 0; y: 0
        width: 520; height: 240
        color: "#20252b"
        property int frames: 0
        onFrameSwapped: frames++
        PillBody {
            id: body
            objectName: "reactiveBody"
            x: 150; y: 100; width: 220; height: 38
            liveHeight: 38
            waterBody: true
            running: true
        }
    }
    Window {
        id: pillScene
        visible: true
        x: 0; y: 300
        width: 700; height: 300
        color: "#20252b"
        Pill {
            id: pill
            x: (pillScene.width - width) / 2; y: 60
            notificationsEnabled: false
        }
    }
    TestCase {
        id: checks
        name: "WaterReactive"
        when: scene.visible && pillScene.visible
        property bool passed: false
        property bool finished: false

        function rgb(hex) { const c = Qt.color(hex); return { r: c.r, g: c.g, b: c.b } }

        function tintRules() {
            const covers = ["#ffffff", "#000000", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", "#808080", "#ff7a00"]
            const themes = {
                dark: { faces: [rgb("#2a2c33"), rgb("#17181c")], ink: rgb("#e6e8ef") },
                light: { faces: [rgb("#eceef4"), rgb("#f6f7fb")], ink: rgb("#1b1c20") },
                extremeDark: { faces: [rgb("#000000"), rgb("#050507")], ink: rgb("#ffffff") },
                extremeLight: { faces: [rgb("#ffffff"), rgb("#fafafa")], ink: rgb("#000000") },
                // The theme actually loaded in this session.
                live: { faces: [rgb(Theme.cardTop.toString()), rgb(Theme.cardBot.toString())], ink: rgb(Theme.foreground.toString()) }
            }
            let nonzero = 0, minMargin = Infinity, worstDrop = 0, report = []
            for (const name in themes) {
                const t = themes[name]
                for (const cover of covers) {
                    const tint = rgb(cover)
                    const m = WR.tintAmount(tint, t.faces, t.ink)
                    verify(m >= 0 && m <= 0.12 + 1e-12, name + " " + cover + " share " + m)
                    let before = Infinity, after = Infinity
                    for (const face of t.faces) {
                        before = Math.min(before, WR.contrast(t.ink, face))
                        after = Math.min(after, WR.contrast(t.ink, WR.mix(face, tint, m)))
                    }
                    const floor = Math.min(before, WR.contrastFloor)
                    verify(after + 1e-9 >= floor, name + " " + cover + " contrast " + after + " < " + floor)
                    minMargin = Math.min(minMargin, after - floor)
                    worstDrop = Math.max(worstDrop, before - after)
                    if (m > 0) nonzero++
                    report.push(name + ":" + cover + "=" + m.toFixed(3) + " (" + before.toFixed(1) + "->" + after.toFixed(1) + ")")
                }
            }
            verify(nonzero > 10, "the guard must still allow tint for most covers (" + nonzero + ")")
            // Pure white/black glass faces with opposite ink cannot lose anything: black cover on a dark theme.
            compare(WR.tintAmount(rgb("#000000"), themes.dark.faces, themes.dark.ink), 0.12)
            // An impossible case drops to zero instead of violating the floor.
            compare(WR.tintAmount(rgb("#ffffff"), [rgb("#8a8a8a")], rgb("#ffffff")), 0)
            console.info("TINT " + report.join(" | "))
            console.info("PASS: WaterReactive tint <=12% and contrast >= min(before,7) for extreme covers in dark/light/live themes; min margin "
                + minMargin.toFixed(2) + ", worst absolute drop " + worstDrop.toFixed(2))
        }

        function rippleRules() {
            fuzzyCompare(WR.rippleAmp(0.05), 0.5, 1e-9)
            fuzzyCompare(WR.rippleAmp(-0.05), 0.5, 1e-9)
            fuzzyCompare(WR.rippleAmp(0.02), 0.2, 1e-9)
            compare(WR.rippleAmp(0.5), 1)
            compare(WR.rippleAmp(0.001), 0)
            fuzzyCompare(WR.rippleEnvelope(1, 0), 1, 1e-9)
            compare(WR.rippleEnvelope(1, 1), 0)
            verify(WR.rippleEnvelope(1, 0.3) > WR.rippleEnvelope(1, 0.6))
            // Restart continues from what is visible and stays bounded; never sums past 1.
            let level = 0
            for (let i = 0; i < 12; ++i) level = WR.rippleRestart(level, 0.05)
            compare(level, 1)
            fuzzyCompare(WR.rippleRestart(WR.rippleEnvelope(0.5, 0.5), 0.05), 0.5 * 0.25 + 0.5, 1e-9)
        }

        function bassRules() {
            // One time constant of the specified attack / release.
            fuzzyCompare(WR.bassStep(0, 1, 0.040), 1 - Math.exp(-1), 1e-9)
            fuzzyCompare(WR.bassStep(1, 0, 0.220), Math.exp(-1), 1e-9)
            let env = 0
            for (let i = 0; i < 400; ++i) env = WR.bassStep(env, 1, 1 / 240)
            fuzzyCompare(env, 1, 0.001)
            for (let i = 0; i < 4000 && env > 0; ++i) env = WR.bassStep(env, 0, 1 / 240)
            compare(env, 0)
            compare(WR.bassGain(0), 1)
            fuzzyCompare(WR.bassGain(1), 1.08, 1e-12)
            compare(WR.bassGain(7), WR.bassGain(1))
            compare(WR.bassGain(-3), 1)
            for (let e = 0; e <= 1.0001; e += 0.05)
                verify(Math.abs(WR.bassGain(e) - 1) <= 0.08 + 1e-12)
            console.info("PASS: WaterReactive ripple amplitude proportional/bounded/restarting; bass attack 40 ms, release 220 ms, gain within +-8%")
        }

        function framesIn(ms) {
            const before = scene.frames
            wait(ms)
            return scene.frames - before
        }

        function stepMs(ms) { for (let t = 0; t < ms; t += 4) { body.shader.advanceDecor(0.004) } }

        function fallbackRules(b, why) {
            b.adjust("volume", 0.5, false)
            compare(b.rippleLevel, 0, why)
            compare(b.shader.rippleAmp, 0, why)
            compare(b.shader.bassGain, 1, why)
            compare(b.tintShown, 0, why)
            compare(b.shader.tintPresence, 0, why)
            verify(!b.bassMoving, why)
        }

        function liveRules() {
            const sw = !body.shaderSupported
            body.reduceMotion = false
            if (sw) {
                // Software: everything reactive resolves to nothing, without clocks.
                verify(!body.waterActive)
                body.tintColor = "#2a6bff"; body.tintOn = true
                body.bassLive = true; body.bassTarget = 1
                fallbackRules(body, "software")
                compare(framesIn(150), 0, "software draws no reactive frames")
                console.info("PASS: WaterReactive software fallback (no ripple, bass, tint presence or frames); live checks NOT VERIFIED")
                body.tintOn = false; body.bassLive = false
                return
            }
            tryVerify(() => body.waterActive, 3000)
            wait(300)
            verify(body.shader.status !== ShaderEffect.Error, body.shader.log)
            // Rest: nothing requests frames.
            tryVerify(() => !body.engine.needsFrames && !body.shader.parametersChanging, 3000)
            wait(200)
            compare(framesIn(250), 0, "idle without music: 0 frames")
            compare(body.shader.rippleAmp, 0)
            compare(body.shader.bassGain, 1)
            compare(body.shader.tintPresence, 0)

            // ---- Ripple ----
            body.adjust("volume", 0.50, false)           // first event: one typical step
            fuzzyCompare(body.rippleLevel, 0.5, 1e-6)
            fuzzyCompare(body.shader.rippleAmp, 0.5, 1e-6)
            const t0 = Date.now()
            verify(body.shader.rippleT < 0.2)
            wait(180)
            const progress = body.shader.rippleT
            verify(progress > 0.2 && progress < 0.7, "ring travelling (" + progress + ")")
            // Repeated press: restarts from the visible amplitude, bounded, one animation.
            const visible = WR.rippleEnvelope(body.rippleLevel, progress)
            body.adjust("volume", 0.55, false)           // +0.05 -> +0.5
            verify(body.rippleLevel <= 1 && body.rippleLevel >= visible + 0.4, "restart level " + body.rippleLevel + " visible " + visible)
            verify(body.shader.rippleT < 0.15, "restarted ring")
            tryVerify(() => body.shader.rippleAmp === 0, 1200)
            const elapsed = Date.now() - t0
            verify(elapsed > 180 + 380 && elapsed < 180 + 650, "ring lifetime after restart ~450 ms (" + (elapsed - 180) + ")")
            tryVerify(() => !body.shader.parametersChanging, 2000)
            wait(150)
            compare(framesIn(250), 0, "after the ring: 0 frames")
            // Proportional to the change; a change of zero is not feedback.
            body.lastVolume = 0.50; body.adjust("volume", 0.52, false)
            fuzzyCompare(body.rippleLevel, 0.2, 1e-6)
            tryVerify(() => body.rippleLevel === 0, 1200)
            body.lastVolume = 0.50; body.adjust("volume", 0.50, false)
            compare(body.rippleLevel, 0)
            body.lastBrightness = 0.2; body.adjust("brightness", 0.3, false)
            fuzzyCompare(body.rippleLevel, 1, 1e-6)
            tryVerify(() => body.rippleLevel === 0, 1200)
            body.adjust("mic", 0.9, false)
            compare(body.rippleLevel, 0)
            wait(150)
            console.info("PASS: WaterReactive ripple restarts without stacking, ~450 ms, 0 frames afterwards")

            // ---- Bass ----
            compare(body.shader.bassGain, 1)
            body.bassLive = true; body.bassTarget = 0.8
            verify(body.bassMoving)
            const f0 = scene.frames
            tryVerify(() => body.bassEnv > 0.5, 1000)
            verify(scene.frames > f0, "frames run while Cava feeds data")
            let top = 0
            for (let i = 0; i < 40; ++i) { top = Math.max(top, body.shader.bassGain - 1); wait(10) }
            verify(top > 0.04 && top <= 0.08 + 1e-9, "bass modulation bounded (" + top + ")")
            body.bassTarget = 1.0
            wait(150)
            verify(body.shader.bassGain <= 1.08 + 1e-9)
            // Pause: relaxes to exactly 1 and stops asking for frames.
            body.bassLive = false
            tryCompare(body, "bassEnv", 0, 3000)
            compare(body.shader.bassGain, 1)
            verify(!body.bassMoving)
            tryVerify(() => !body.shader.parametersChanging, 2000)
            wait(100)
            compare(framesIn(300), 0, "paused music: 0 frames")
            // Live but silent (Cava stalled): target 0 stops the clock too.
            body.bassLive = true; body.bassTarget = 0
            verify(!body.bassMoving)
            wait(100)
            const silentFrames = framesIn(250)
            verify(silentFrames <= 2, "silent settle frames " + silentFrames)
            compare(framesIn(250), 0, "silent frames after settling: 0")
            body.bassLive = false
            // Deterministic envelope through the same clock that integrates decorations.
            body.bassLive = true; body.bassTarget = 1
            body.shader.advanceDecor(0.040)
            fuzzyCompare(body.bassEnv, 1 - Math.exp(-1), 0.2)
            body.bassLive = false; body.bassTarget = 0
            tryCompare(body, "bassEnv", 0, 3000)
            console.info("PASS: WaterReactive bass envelope bounded +8%, frames only while data flows, 0 frames when paused/silent")

            // ---- Tint ----
            body.tintColor = "#2a6bff"; body.tintOn = true
            verify(body.tintValid)
            tryVerify(() => body.shader.tintPresence > 0.5, 3000)
            tryCompare(body.shader, "tintPresence", 1, 3000)
            verify(body.shader.tintTo.w > 0 && body.shader.tintTo.w <= 0.12 + 1e-9, "share " + body.shader.tintTo.w)
            tryVerify(() => !body.shader.parametersChanging, 3000)
            wait(100)
            compare(framesIn(250), 0, "steady tint: 0 frames")
            // New track: the colour crosses with a spring from the one on screen, no timer overshoot.
            const old = Qt.vector4d(body.shader.tintTo.x, body.shader.tintTo.y, body.shader.tintTo.z, 0)
            body.tintColor = "#ff3b30"
            verify(body.tintCross.integrating && body.tintCross.value === 0)
            fuzzyCompare(body.shader.tintFrom.x, old.x, 0.01)
            fuzzyCompare(body.shader.tintTo.x, 1, 0.01)
            let last = 0, peak = 0
            for (let i = 0; i < 60 && body.tintCross.integrating; ++i) { wait(10); peak = Math.max(peak, body.tintCross.value); verify(body.tintCross.value >= last - 1e-9); last = body.tintCross.value }
            tryCompare(body.tintCross, "value", 1, 2000)
            verify(peak <= 1.0 + 1e-9, "critically damped, no overshoot (" + peak + ")")
            tryVerify(() => !body.shader.parametersChanging, 3000)
            wait(100)
            compare(framesIn(250), 0, "settled crossing: 0 frames")
            // Pause relaxes to neutral in ~1.2 s.
            const p0 = Date.now()
            body.tintOn = false
            wait(500)
            verify(body.shader.tintPresence > 0.1 && body.shader.tintPresence < 0.9, "mid relax " + body.shader.tintPresence)
            tryCompare(body.shader, "tintPresence", 0, 1600)
            const relax = Date.now() - p0
            verify(relax > 900 && relax < 1650, "relax ~1.2 s (" + relax + ")")
            tryVerify(() => !body.shader.parametersChanging, 3000)
            wait(100)
            compare(framesIn(250), 0, "neutral again: 0 frames")
            console.info("PASS: WaterReactive tint share <=12%, spring crossing without overshoot, ~1.2 s relax, 0 frames when settled")

            // ---- Fallbacks with a real renderer ----
            body.tintColor = "#2a6bff"; body.tintOn = true; body.bassLive = true; body.bassTarget = 1
            body.adjust("volume", 0.8, false)
            tryVerify(() => body.rippleLevel > 0, 500)
            body.reduceMotion = true
            verify(!body.waterActive)
            compare(body.rippleLevel, 0)
            fallbackRules(body, "reduceMotion")
            body.reduceMotion = false
            body.waterBody = false
            verify(!body.waterActive)
            fallbackRules(body, "waterBody=false")
            body.waterBody = true
            tryVerify(() => body.waterActive, 1000)
            body.tintOn = false; body.bassLive = false
            const broken = Qt.createQmlObject('import QtQuick; import "body"; PillBody { width: 220; height: 38; '
                + 'waterBody: true; running: true; tintOn: true; tintColor: "#2a6bff"; bassLive: true; bassTarget: 1; '
                + 'shader.fragmentShader: Qt.resolvedUrl("body/shaders/water-intentionally-missing.frag.qsb") }',
                scene.contentItem, "brokenReactiveBody")
            tryCompare(broken.shader, "status", ShaderEffect.Error, 3000)
            verify(broken.shaderFailed && !broken.waterActive)
            fallbackRules(broken, "shader error")
            broken.destroy()
            console.info("PASS: WaterReactive fallbacks (reduceMotion, waterBody=false, shader error) give no ripple, bass or tint")
        }

        function pillWiring() {
            tryVerify(() => Config.loaded, 2000)
            compare(Config.appearance.waterReactsToMusic, true, "default on")
            verify(!Config.update({appearance: {waterReactsToMusic: "yes"}}).ok)
            const pb = findChild(pill, "pillBody")
            const adapter = findChild(pill, "pillStatusAdapter")
            verify(pb && adapter)
            adapter.showVolume(0.4, false)
            compare(pb.lastVolume, 0.4)
            adapter.showBrightness(0.7)
            compare(pb.lastBrightness, 0.7)
            adapter.showMic(0.2, false)
            compare(pb.lastVolume, 0.4, "mic is not a volume ripple")
            // No player: no tint, no bass, whatever the setting says.
            verify(!pb.tintOn && !pb.bassLive)
            verify(Config.update({appearance: {waterReactsToMusic: false}}).ok)
            verify(!pb.bassLive)
            verify(Config.update({appearance: {waterReactsToMusic: true}}).ok)
            console.info("PASS: WaterReactive Pill wiring (OSD volume/brightness reach the body, mic does not; setting validated; idle without player)")
        }

        function test_reactive() {
            try {
                tintRules()
                rippleRules()
                bassRules()
                pillWiring()
                tryVerify(() => Config.loaded, 2000)
                verify(Config.update({appearance: {waterBody: true, reduceMotion: false, reduceTransparency: false}}).ok)
                liveRules()
                passed = true
            } catch (error) {
                console.error("FAIL: WaterReactive " + error + " " + error.stack)
                throw error
            } finally { finished = true }
        }
    }
    Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
}
