import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "body"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 1000; height: 800
        color: "#20252b"
        Pill {
            id: pill
            x: (scene.width - width) / 2; y: 100
            notificationsEnabled: false
        }
        BodyEngine {
            id: idleEngine
            active: false
            manualStep: true
            sleepWhenStill: true
            breathe: false
            mood: "curiosa"
            beatEnvelope: 0
        }
        Item {
            x: 20; y: 700; width: 220; height: 38
            PillMaterial {
                id: decorationProbe
                shaderActive: true
                materialAwake: true
                materialPulse: .6
                mode: "rest"
            }
        }
        PillBody {
            id: presenceProbe
            width: 220; height: 38
            waterBody: true
            running: false
            dock: Qt.vector3d(200, 150, 12)
        }
        BodyShader {
            id: shaderProbe
            x: 20; y: 520; width: 200; height: 160
            water: 1; reading: 0; fillAlpha: 1
            pillCx: 100; pillCy: 80; pillHalfW: 60; pillHalfH: 40; pillRadius: 20
            bulgeWeight: 0; glow: 0; spec: 0; wallMix: 0
            outsideOpacity: 0; shadowExposure: 0
            colTop: "#808080"; colBase: "#808080"
            colA: "black"; colB: "black"; colC: "black"; colBg: "black"
        }
        TestCase {
            id: checks
            name: "WaterBody"
            when: scene.visible
            property bool passed: false
            property bool finished: false
            function roundOne() {
                // W4: no legacy decoration instances or FBO under water.
                const decorations = findChild(decorationProbe, "pillMaterialDecorations")
                verify(!decorations.active && decorations.item === null)
                for (const name of ["Halo", "InnerGlow", "AccentTop", "AccentTint", "Shadow"])
                    verify(!findChild(decorationProbe, "pillMaterial" + name), name)
                // 3/8: six consecutive unchanged frames, no layer, no input array when off.
                compare(shaderProbe.renderInputs, null)
                shaderProbe.time += 1
                compare(shaderProbe.renderInputs, null)
                shaderProbe.cacheWhenStill = true
                compare(shaderProbe.unchangedFrames, 0)
                verify(shaderProbe.parametersChanging && !shaderProbe.layer.enabled)
                wait(20)
                shaderProbe.warm = .1
                compare(shaderProbe.unchangedFrames, 0)
                tryCompare(shaderProbe, "unchangedFrames", shaderProbe.quietFrames, 2000)
                compare(shaderProbe.quietFrames, 6)
                verify(!shaderProbe.settling && !shaderProbe.layer.enabled)
                shaderProbe.warm = 0
                compare(shaderProbe.unchangedFrames, 0)
                verify(shaderProbe.parametersChanging)
                shaderProbe.cacheWhenStill = false
                verify(!shaderProbe.settling)
                compare(shaderProbe.renderInputs, null)
                // 5: retarget preserves both value and velocity; bud and file share presence.
                const presence = findChild(presenceProbe, "pillBodyRestPresence")
                presence.manualStep = true
                presence.active = true
                presenceProbe.engine.result = {pill: [203, 111, 112, 20],
                    bulge: [200, 130, 10, 1], glow: 0, mood: "curiosa"}
                presenceProbe.docked = true
                presenceProbe.resting = true
                presence.snap(1)
                const b = presenceProbe.shader.bulge, d = presenceProbe.shader.drop0
                const bulgeRadius = b.z, dropRadius = d.z
                const cx = presenceProbe.shader.pillCx, hh = presenceProbe.shader.pillHalfH
                presenceProbe.resting = false
                compare(presence.value, 1)
                compare(presenceProbe.shader.bulge, b)
                compare(presenceProbe.shader.drop0, d)
                compare(presenceProbe.shader.bulge.z, bulgeRadius)
                compare(presenceProbe.shader.drop0.z, dropRadius)
                compare(presenceProbe.shader.pillCx, cx)
                compare(presenceProbe.shader.pillHalfH, hh)
                presence.step(.08)
                verify(presence.value > 0 && presence.value < 1)
                verify(presenceProbe.shader.bulge.z > 0 && presenceProbe.shader.bulge.z < bulgeRadius)
                verify(presenceProbe.shader.drop0.z > 0 && presenceProbe.shader.drop0.z < dropRadius)
                verify(presenceProbe.shader.pillCx > 200 && presenceProbe.shader.pillCx < cx)
                const value = presence.value, velocity = presence.velocity
                presenceProbe.resting = true
                compare(presence.value, value); compare(presence.velocity, velocity)
                presence.active = false
                presenceProbe.resting = false
                compare(presence.value, 0)
                compare(presenceProbe.shader.bulge.z, 0)
                compare(presenceProbe.shader.drop0.z, 0)
                console.info("PASS: WaterBody R1 decorations, six-frame quiet detection, direct render, spring continuity, lazy inputs")
            }
            function shaderPixels() {
                // 1/7: execute the compiled shader; no source-string proxy for pixel behavior.
                tryCompare(shaderProbe, "status", ShaderEffect.Compiled, 3000)
                // Some backends (RHI/OpenGL offscreen) grab onto an opaque window colour, others onto
                // transparency: measure the shadow as coverage relative to the exposure-0 capture.
                shaderProbe.shadowExposure = 0
                waitForRendering(shaderProbe)
                const zero = grabImage(shaderProbe)
                const sx = zero.width / shaderProbe.width, sy = zero.height / shaderProbe.height
                const opaque = zero.alpha(2, 2) === 255
                const cover = (img, x, y) => {
                    const X = Math.floor(x * sx), Y = Math.floor(y * sy)
                    return opaque ? (zero.red(X, Y) - img.red(X, Y)) / Math.max(1, zero.red(X, Y)) * 255 : img.alpha(X, Y)
                }
                shaderProbe.shadowExposure = 1
                waitForRendering(shaderProbe)
                const full = grabImage(shaderProbe)
                let maximum = 0
                for (let y = 125; y < 148; ++y)
                    for (let x = 70; x < 130; ++x)
                        maximum = Math.max(maximum, cover(full, x, y))
                verify(maximum > 0 && maximum <= (opaque ? 48 : 36), "shadow capped at .14 independently of outsideOpacity=0 (max " + maximum + ")")
                shaderProbe.shadowExposure = .5
                waitForRendering(shaderProbe)
                const half = grabImage(shaderProbe)
                verify(Math.abs(cover(half, 100, 128) - cover(full, 100, 128) / 2) <= (opaque ? 10 : 1))
                compare(opaque ? zero.red(Math.floor(100 * sx), Math.floor(128 * sy)) - zero.red(Math.floor(100 * sx), Math.floor(156 * sy)) : zero.alpha(Math.floor(100 * sx), Math.floor(128 * sy)), 0, "no resting shadow")
                let low = 255, high = 0
                for (let x = 80; x < 120; ++x) {
                    const red = zero.red(Math.floor(x * sx), Math.floor(80 * sy))
                    low = Math.min(low, red); high = Math.max(high, red)
                }
                verify(high > low && high - low <= 3, "cheap deep interior has spatial dithering")
                shaderProbe.time += 10
                waitForRendering(shaderProbe)
                const later = grabImage(shaderProbe)
                for (let x = 80; x < 120; ++x)
                    compare(later.pixel(Math.floor(x * sx), Math.floor(80 * sy)),
                        zero.pixel(Math.floor(x * sx), Math.floor(80 * sy)), "dither is time-independent")
                console.info("PASS: WaterBody R1 rendered shadow cap/exposure and interior dithering")
            }
            function shape(body, material) {
                // The fading rest spring may still add its bounded expressive width/height.
                fuzzyCompare(body.shader.pillHalfW * 2, pill.width + pill.fluidCaptureExtra + pill.fluidCaptureLeftExtra,
                    .001 + 16 * body.shader.designScale * body.restExposure)
                fuzzyCompare(body.shader.pillHalfH * 2, pill.height, .001 + 12 * body.shader.designScale * body.restExposure)
                compare(body.shader.pillRadius, material.bodyRadius)
                fuzzyCompare(body.shader.fillAlpha, material.bodyAlpha, .001)
                compare(body.shader.reading, material.readingExposure)
            }
            function stableExposure(body, ms) {
                for (let elapsed = 0; elapsed < ms; elapsed += 8) {
                    compare(body.exposure, 1, "no handoff during morph")
                    compare(body.shader.opacity, 1, "no compensated alpha")
                    verify(!body.shader.layer.enabled, "movement draws directly without a layer")
                    if (body.shader.parametersChanging || !body.shader.cacheWhenStill)
                        compare(findChild(pill, "pillBodyCache").sourceItem, null)
                    shape(body, findChild(pill, "pillMaterial"))
                    wait(8)
                }
            }
            function test_water() {
                try {
                    tryVerify(() => Config.loaded, 2000)
                    compare(Config.appearance.waterBody, false, "run with an empty temporary config")
                    verify(!Config.update({appearance: {waterBody: "true"}}).ok)
                    verify(Config.update({appearance: {waterBody: true, personality: false,
                        liquidSurfaces: false, reduceMotion: false, reduceTransparency: false}}).ok)
                    const body = findChild(pill, "pillBody")
                    const material = findChild(pill, "pillMaterial")
                    const shadow = findChild(pill, "pillMaterialShadow")
                    const cache = findChild(pill, "pillBodyCache")
                    verify(body && material && cache)
                    // The unloaded Loader item is deleted on the next event loop turn.
                    tryVerify(() => !!findChild(pill, "pillMaterialShadow") === !body.waterActive, 1000)
                    wait(700)
                    roundOne()
                    compare(body.shader.outsideOpacity, 0)
                    compare(body.shader.shadowExposure, 0, "resting shadow exposure")
                    // Independent deterministic clock: a held pointer / fixed external beat settles.
                    idleEngine.active = true
                    idleEngine.pointer = Qt.point(110, 0)
                    idleEngine.music = true
                    for (let i = 0; i < 1200; ++i) idleEngine.advance(1 / 60)
                    verify(!idleEngine.needsFrames, "static inputs do not request frames")
                    idleEngine.manualStep = false
                    wait(100)
                    const ticks = idleEngine.advanceCount
                    wait(100)
                    compare(idleEngine.advanceCount, ticks)
                    idleEngine.reduceMotion = true
                    verify(!idleEngine.frameRunning && !idleEngine.timerRunning)
                    idleEngine.active = false
                    const stoppedTicks = idleEngine.advanceCount
                    idleEngine.baseW += 10
                    idleEngine.pointer = Qt.point(10, 10)
                    wait(50)
                    compare(idleEngine.advanceCount, stoppedTicks)

                    if (!body.shaderSupported) {
                        compare(body.exposure, 0)
                        compare(material.opacity, 1)
                        verify(!material.shaderActive && !body.engine.active)
                        pill.surface = "calendar"
                        wait(700)
                        shape(body, material)
                        fuzzyCompare(body.shader.shadowExposure, material.readingExposure * pill.fluidEdgeExposure, .001)
                        verify(body.shader.shadowExposure > 0)
                        verify(shadow.layer.enabled, "software keeps the original shadow")
                        console.info("PASS: WaterBody config, software fallback, geometry/uniform wiring, idle engine; RHI checks NOT VERIFIED")
                        passed = true
                        return
                    }
                    shaderPixels()
                    // Qt only reports Compiled for the first instance of a shared .qsb; the pill
                    // still renders (checked by pixels), so only an error status is decisive here.
                    verify(body.shader.status !== ShaderEffect.Error, body.shader.log)
                    compare(body.exposure, 1)
                    verify(material.shaderActive)
                    compare(material.opacity, 1) // Wrapper remains for notification/media/reception.
                    for (const route of ["launcher", "media", "calendar", "utils"]) {
                        pill.surface = route
                        stableExposure(body, 240)
                        wait(700)
                        compare(body.exposure, 1)
                        shape(body, material)
                        verify(!findChild(pill, "pillMaterialShadow"), route + " has no material shadow instance")
                        fuzzyCompare(body.shader.shadowExposure, material.readingExposure * pill.fluidEdgeExposure, .001)
                        verify(body.shader.shadowExposure > 0)
                        verify(!findChild(pill, "pillMaterialDepthLight"))
                        verify(!findChild(pill, "pillMaterialDepthShade"))
                        tryVerify(() => !body.engine.needsFrames && !body.shader.parametersChanging, 3000)
                        verify(cache.visible && cache.hideSource && !cache.live)
                        verify(!body.shader.layer.enabled, "stationary glass is a texture")
                        fuzzyCompare((body.sceneOrigin.x + cache.x) * cache.dpr, Math.round((body.sceneOrigin.x + cache.x) * cache.dpr), .001)
                        fuzzyCompare((body.sceneOrigin.y + cache.y) * cache.dpr, Math.round((body.sceneOrigin.y + cache.y) * cache.dpr), .001)
                        const count = body.engine.advanceCount
                        wait(100)
                        compare(body.engine.advanceCount, count)
                        pill.surface = ""
                        stableExposure(body, 240)
                        wait(700)
                    }
                    Config.update({appearance: {personality: true, liquidSurfaces: true, bodyBreath: true}})
                    tryVerify(() => body.resting && body.engine.breathe, 3000)
                    wait(300)
                    verify(!body.shader.cacheWhenStill && !body.shader.layer.enabled && cache.sourceItem === null)
                    wait(300)
                    verify(!body.shader.cacheWhenStill && cache.sourceItem === null, "no 30Hz cache toggling")
                    pill.respond("finished")
                    wait(50)
                    verify(!body.shader.layer.enabled, "contenta never enables a layer")
                    Config.update({appearance: {personality: false, liquidSurfaces: false, bodyBreath: false}})
                    tryVerify(() => body.restExposure === 0, 3000)
                    // Reverse before reaching the destination. Geometry belongs to the existing morph.
                    pill.surface = "launcher"
                    wait(80)
                    const w = pill.width, h = pill.height
                    pill.surface = ""
                    compare(pill.width, w); compare(pill.height, h)
                    stableExposure(body, 100)
                    const w2 = pill.width, h2 = pill.height
                    pill.surface = "calendar"
                    compare(pill.width, w2); compare(pill.height, h2)
                    stableExposure(body, 160)
                    Config.update({appearance: {reduceMotion: true}})
                    wait(20)
                    verify(!body.engine.frameRunning && !body.engine.timerRunning)
                    pill.surface = "media"
                    wait(20)
                    fuzzyCompare(pill.width, pill.targetW, .01)
                    fuzzyCompare(pill.height, pill.targetH, .01)
                    // Water mode hands reduceMotion to the legacy material (W4), so the body steps aside.
                    compare(body.exposure, body.waterBody ? 0 : 1)
                    pill.fluidJoined = true
                    compare(body.shader.edgeExposure, 0)
                    pill.fluidCaptureExtra = 18; pill.fluidCaptureLeftExtra = 12
                    shape(body, material)
                    fuzzyCompare(body.shader.x + body.shader.pillCx - body.shader.pillHalfW, -12, .001)
                    pill.fluidJoined = false
                    pill.fluidCaptureExtra = 0; pill.fluidCaptureLeftExtra = 0
                    Config.update({appearance: {reduceTransparency: true}})
                    compare(body.exposure, 0)
                    verify(!material.shaderActive)
                    Config.update({appearance: {reduceTransparency: false, reduceMotion: false}})
                    compare(body.exposure, 1)
                    pill.visible = false
                    compare(body.exposure, 0)
                    verify(!body.engine.active && !body.engine.frameRunning)
                    pill.visible = true
                    // Deliberately break a real shader, rather than mocking the error flag. It must fail
                    // at load time: swapping the URL of a shader that has already drawn crashes Qt 6.12
                    // inside QQuickShaderEffect::updatePaintNode, and the product never does that.
                    const broken = Qt.createQmlObject('import QtQuick; import "body"; PillBody { width: 220; height: 38; '
                        + 'waterBody: true; running: true; shader.fragmentShader: Qt.resolvedUrl("body/shaders/water-intentionally-missing.frag.qsb") }',
                        scene.contentItem, "brokenWaterBody")
                    tryCompare(broken.shader, "status", ShaderEffect.Error, 3000)
                    verify(broken.shaderFailed && !broken.waterActive)
                    compare(broken.exposure, 0)
                    verify(!broken.engine.active && !broken.visible)
                    broken.destroy()
                    // Pill wires material.shaderActive to body.waterActive: the same path as above
                    // (reduceTransparency) restores the complete original material and its shadow.
                    Config.update({appearance: {reduceTransparency: true}})
                    verify(!material.shaderActive && material.opacity === 1)
                    tryVerify(() => { const s = findChild(pill, "pillMaterialShadow"); return !!s && s.layer.enabled }, 1000, "inactive water restores the complete original material")
                    Config.update({appearance: {reduceTransparency: false}})
                    console.info("PASS: WaterBody no handoff, routes, cache, shadow FBO, fallback, reduced motion and interruption")
                    passed = true
                } catch (error) {
                    console.error("FAIL: WaterBody " + error + " " + error.stack)
                    throw error
                } finally { finished = true }
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
    }
}
