import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
import "body"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 1000; height: 850
        color: "#20252b"
        Item { id: origin; x: 250; y: 100; width: 120; height: 38 }
        // Exercises loader/uniform contracts on software too; pixels use the real renderer.
        QtObject { id: available; property bool waterActive: true; property bool messengerActive: false }
        PillBody {
            id: body
            x: origin.x; y: origin.y; width: origin.width; height: origin.height
            waterBody: true
            resting: false
            companion0: drop
            captureExtra: drop.leftSide || drop.centered ? 0 : drop.captureExtra
            captureLeftExtra: drop.leftSide ? drop.captureExtra : 0
        }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: origin
            waterBody: available
            manualStep: true
            expandedContent: Component { Item {} }
        }
        BodyShader {
            id: pixels
            x: 20; y: 570; width: 320; height: 200
            water: 1; reading: .7; fillAlpha: .85
            pillCx: 110; pillCy: 80; pillHalfW: 60; pillHalfH: 19; pillRadius: 19
            companionBox0: Qt.vector4d(200, 80, 20, 19)
            companionShape0: Qt.vector2d(19, 32)
            colTop: "#808080"; colBase: "#808080"
            colA: "black"; colB: "black"; colC: "black"; colBg: "black"
            wallMix: 0; spec: .25; glow: 0; outsideOpacity: 0
            shadowExposure: .7
        }
        TestCase {
            id: checks
            name: "WaterDrop"
            when: scene.visible
            property bool passed: false
            property bool finished: false
            function geometry() { return [drop.xPos, drop.yPos, drop.wPos, drop.hPos, drop.captureExtra, drop.fieldSpring.value] }
            function same(before) {
                const after = geometry()
                for (let i = 0; i < before.length; ++i)
                    verify(Math.abs(after[i] - before[i]) <= 1, "retarget discontinuity <=1px, coordinate " + i)
            }
            function advance(count) { for (let i = 0; i < count; ++i) drop.advanceMotion(1 / 240) }
            function test_drop() {
                try {
                    tryVerify(() => Config.loaded, 2000)
                    Config.update({appearance: {reduceMotion: false, personality: false, liquidSurfaces: false}})
                    drop.open = true
                    wait(1)
                    verify(drop.waterActive)
                    const material = findChild(drop, "companionMaterialLoader")
                    const neck = findChild(drop, "companionNeckLoader")
                    verify(!material.active && material.item === null, "no second PillMaterial instance")
                    verify(!neck.active && neck.item === null, "no FluidNeck instance")
                    verify(!findChild(drop, "companionLegacyMaterial") && !findChild(drop, "companionLegacyNeck"))
                    compare(drop.fieldSpring.spring, Motion.strokeSpring.lift)
                    verify(drop.fieldSpring.manualStep && !drop.motionRunning)
                    verify(!drop.children.find(child => child.layer.enabled), "no cut layer on unified path")
                    // Hysteresis uses geometry, including reflected coordinates.
                    drop.phase = "companion"; drop.wPos = 38; drop.hPos = 38; drop.yPos = origin.y
                    drop.xPos = drop.capX + 1.1 * (drop.capRadius + drop.dropRadius) - 19
                    drop.bond = false; drop.updateBond(); verify(!drop.bond)
                    drop.xPos = drop.capX + .99 * (drop.capRadius + drop.dropRadius) - 19
                    drop.updateBond(); verify(drop.bond)
                    drop.xPos = drop.capX + 1.1 * (drop.capRadius + drop.dropRadius) - 19
                    drop.updateBond(); verify(drop.bond, "holds past birth threshold")
                    drop.fieldSpring.snap(0)
                    drop.fieldSpring.step(1 / 60)
                    verify(drop.fieldSpring.value > 0 && drop.fieldSpring.value < drop.fieldSpring.target)
                    compare(drop.fieldShape.y, drop.fieldSpring.value)
                    const fusion = drop.fieldSpring.value, fusionVelocity = drop.fieldSpring.velocity
                    drop.xPos = drop.capX + 1.31 * (drop.capRadius + drop.dropRadius) - 19
                    drop.updateBond(); verify(!drop.bond)
                    compare(drop.fieldSpring.value, fusion); compare(drop.fieldSpring.velocity, fusionVelocity)
                    compare(drop.fieldSpring.target, 0)
                    drop.phase = "retornando"
                    drop.xPos = drop.capX + 1.29 * (drop.capRadius + drop.dropRadius) - 19
                    drop.updateBond(); verify(drop.bond, "return joins at break threshold")
                    // Opening -> closing -> reopening keeps presentation AND velocities.
                    drop.expanded = true; drop.start(); advance(18)
                    let before = geometry(), velocity = drop.vx, neckVelocity = drop.fieldSpring.velocity
                    drop.open = false; same(before)
                    compare(drop.vx, velocity); compare(drop.fieldSpring.velocity, neckVelocity)
                    advance(12)
                    before = geometry(); velocity = drop.vx; neckVelocity = drop.fieldSpring.velocity
                    drop.open = true; same(before)
                    compare(drop.vx, velocity); compare(drop.fieldSpring.velocity, neckVelocity)
                    // Measure ordinary travel separately from instantaneous retarget jumps.
                    // A moving card can cover >1px per frame without a discontinuity.
                    let maximum = 0
                    for (let frame = 0; frame < 12; ++frame) {
                        const previous = geometry()
                        drop.advanceMotion(1 / 60)
                        const after = geometry()
                        for (let i = 0; i < 4; ++i) maximum = Math.max(maximum, Math.abs(after[i] - previous[i]))
                    }
                    console.info("PASS: WaterDrop retarget <=1px with position/velocity preserved, hysteresis; max ordinary 60Hz travel=" + maximum + "px")
                    for (const orientation of ["right", "left", "centered"]) {
                        drop.leftSide = orientation === "left"; drop.centered = orientation === "centered"
                        drop.below = drop.centered
                        advance(600)
                        const box = body.shader.companionBox0
                        fuzzyCompare(body.shader.x + box.x, drop.visualX - origin.x + drop.wPos / 2, .001)
                        fuzzyCompare(body.shader.y + box.y, drop.yPos - origin.y + drop.hPos / 2, .001)
                        compare(box.z, drop.wPos / 2); compare(box.w, drop.hPos / 2)
                        fuzzyCompare(body.shader.x + body.shader.bulge.x, body.engine.bulge.x - body.margin, .001)
                        fuzzyCompare(body.shader.y + body.shader.bulge.y, body.engine.bulge.y - body.margin, .001)
                        compare(body.shader.companionShape0.x, drop.cardRadius)
                        verify(body.shader.x <= drop.fieldBox.x - drop.fieldBox.z - body.margin)
                        verify(body.shader.y + body.shader.height >= drop.fieldBox.y + drop.fieldBox.w + body.margin)
                    }
                    body.companion0 = null
                    for (let slot = 0; slot < 5; ++slot) {
                        body["companion" + slot] = drop
                        const box = body.shader["companionBox" + slot]
                        fuzzyCompare(body.shader.x + box.x, drop.fieldBox.x, .001)
                        fuzzyCompare(body.shader.y + box.y, drop.fieldBox.y, .001)
                        compare(box.z, drop.fieldBox.z)
                        compare(body.shader["companionShape" + slot], drop.fieldShape)
                        body["companion" + slot] = null
                    }
                    body.companion0 = drop
                    drop.manualStep = false
                    tryVerify(() => !drop.motionRunning && !drop.fieldSpring.integrating, 2000)
                    const quiet = geometry()
                    wait(100)
                    compare(geometry(), quiet, "settled field stays quiet without a frame clock")
                    drop.manualStep = true
                    // Disabled/error/reduced transparency are the same renderer-availability contract.
                    available.waterActive = false
                    verify(material.active && material.item !== null && neck.active && neck.item !== null)
                    available.waterActive = true
                    verify(!material.active && !neck.active)
                    Config.update({appearance: {reduceMotion: true}})
                    verify(!drop.waterActive && material.item !== null && neck.item !== null)
                    verify(drop.settled && !drop.fieldSpring.integrating && !drop.motionRunning)
                    drop.open = false
                    compare(drop.phase, "idle"); compare(body.shader.companionBox0.z, 0)
                    Config.update({appearance: {reduceMotion: false}})
                    // Actual hardware/software decision, without the availability fixture.
                    drop.waterBody = body
                    compare(drop.waterActive, body.waterActive)
                    body.waterBody = false
                    verify(!drop.waterActive && material.item !== null && neck.item !== null)
                    body.waterBody = true
                    if (!body.shaderSupported) {
                        verify(!drop.waterActive && material.item !== null)
                        console.info("PASS: WaterDrop loaders, fallback, uniforms, bounds, reduced motion; RHI pixels/cache NOT VERIFIED")
                    } else {
                        verify(body.waterActive)
                        drop.leftSide = false; drop.centered = false; drop.below = false
                        drop.open = true; wait(1)
                        advance(1400)
                        tryVerify(() => !body.shader.parametersChanging, 3000)
                        verify(!body.shader.settling && !body.shader.layer.enabled)
                        verify(!drop.fieldSpring.integrating && !drop.motionRunning)
                        const cache = findChild(body, "pillBodyCache")
                        verify(cache.hideSource && !cache.live)
                        drop.xPos += 2
                        verify(body.shader.parametersChanging && !cache.hideSource, "drop geometry invalidates cache")
                        tryVerify(() => !body.shader.parametersChanging, 3000)
                        verify(cache.hideSource)
                        waitForRendering(pixels)
                        verify(pixels.status !== ShaderEffect.Error, pixels.log)
                        const image = grabImage(pixels), sx = image.width / pixels.width, sy = image.height / pixels.height
                        const luminance = (x, y) => {
                            const X = Math.floor(x * sx), Y = Math.floor(y * sy)
                            return .2126 * image.red(X, Y) + .7152 * image.green(X, Y) + .0722 * image.blue(X, Y)
                        }
                        let jump = 0
                        for (let x = 150; x < 205; ++x) jump = Math.max(jump, Math.abs(luminance(x + 1, 80) - luminance(x, 80)))
                        verify(luminance(175, 80) > 50, "neck is filled across the gap")
                        verify(jump <= 32, "neck adjacent luminance <=32/255: " + jump)
                        console.info("PASS: WaterDrop RHI neck luminance max jump=" + jump + "/255, stationary cache and invalidation")
                        body.shader.fragmentShader = Qt.resolvedUrl("body/shaders/w3-missing.frag.qsb")
                        tryCompare(body.shader, "status", ShaderEffect.Error, 3000)
                        verify(!body.waterActive && !drop.waterActive)
                        verify(material.item !== null && neck.item !== null, "shader error restores companion fallback")
                    }
                    passed = true
                } catch (error) {
                    console.error("FAIL: WaterDrop " + error + " " + error.stack)
                    throw error
                } finally { finished = true }
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
    }
}
