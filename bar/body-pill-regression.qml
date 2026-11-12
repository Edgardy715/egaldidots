import QtQuick
import QtTest
import Quickshell
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 800; height: 500
        color: "#20252b"
        Pill {
            id: pill
            x: (scene.width - width) / 2; y: 80
            notificationsEnabled: false
        }
        TestCase {
            id: checks
            name: "BodyPill"
            when: scene.visible
            property bool passed: false
            property bool finished: false
            function test_integration() {
                try {
                    tryVerify(() => Config.loaded, 2000)
                    verify(Config.update({appearance: {personality: true, liquidSurfaces: true, reduceTransparency: false, reduceMotion: false}}).ok)
                    const body = findChild(pill, "pillBody")
                    const material = findChild(pill, "pillMaterial")
                    verify(body !== null && material !== null)
                    wait(100)
                    if (!body.shaderSupported) {
                        tryCompare(body, "exposure", 0)
                        compare(material.opacity, 1)
                        verify(!body.engine.active)
                        passed = true
                        console.info("PASS: BodyPill software fallback; integration requires RHI/Wayland")
                        return
                    }
                    tryCompare(body, "exposure", 1, 2000)
                    compare(body.shader.status, ShaderEffect.Compiled, body.shader.log)
                    // The resting body is the same glass as PillMaterial: tint and transmission.
                    compare(body.shader.colBase, Theme.cardBot)
                    compare(body.shader.colTop, Theme.cardTop)
                    fuzzyCompare(body.shader.fillAlpha, material.bodyAlpha, 0.001)
                    compare(body.shader.pillRadius, -1)
                    compare(body.hour, pill.now.getHours() + pill.now.getMinutes() / 60)
                    compare(body.engine.beatEnvelope, body.beatEnvelope)
                    verify(!body.breathe)
                    Config.update({appearance: {bodyBreath: true}})
                    compare(body.engine.breathe, true)
                    Config.update({appearance: {bodyBreath: false}})
                    verify(!body.engine.breathe)
                    // Night outranks focus; keep the mood check independent of the clock.
                    Config.update({companion: {reactAtNight: false}})
                    pill.companionCodeFocused = true
                    compare(body.mood, "timida")
                    Config.update({companion: {reactToCode: false}})
                    verify(body.mood !== "timida")
                    Config.update({companion: {reactToCode: true}})
                    pill.companionCodeFocused = false
                    pill.respond("finished")
                    compare(body.mood, "contenta")
                    Config.update({companion: {reactToSystem: false}})
                    verify(body.mood !== "contenta")
                    Config.update({companion: {reactToSystem: true}})
                    wait(700) // Let the initial header/layout morph settle.
                    tryVerify(() => Math.abs(pill.width - pill.restW) < .05, 3000)
                    const w = pill.width, h = pill.height
                    pill.hovered = true; pill.pointerX = w * .7; pill.pointerY = h / 2
                    compare(pill.width, w) // Pointer input must not write layout.
                    wait(150)
                    console.info("Body layout width=" + pill.width + " target=" + pill.targetW + " initial=" + w)
                    tryVerify(() => Math.abs(pill.width - pill.targetW) < .05, 3000)
                    verify(Math.abs(pill.height - h) < 0.05, "Body must not own layout height")
                    verify(body.engine.active)
                    pill.interactionOpen = true
                    tryCompare(body, "exposure", 0)
                    compare(material.opacity, 1)
                    verify(!body.engine.frameRunning && !body.engine.timerRunning)
                    const ticks = body.engine.advanceCount
                    pill.pointerX += 15
                    pill.restLeftWidth = 30
                    wait(100); compare(body.engine.advanceCount, ticks)
                    pill.restLeftWidth = 0
                    pill.interactionOpen = false
                    wait(35)
                    verify(body.exposure > 0 && body.exposure < 1)
                    // Handoff keeps the stacked alpha: material over body equals the material alone.
                    const e = body.exposure, A = body.fillAlpha, bodyA = A * body.shader.opacity
                    fuzzyCompare(A * (1 - e) + bodyA * (1 - A * (1 - e)), A, 0.001)
                    pill.interactionOpen = true
                    compare(body.shader.pillRadius, pill.morphRadius)
                    tryCompare(body, "exposure", 0)
                    pill.interactionOpen = false
                    tryCompare(body, "exposure", 1)
                    pill.surface = "calendar"
                    tryCompare(body, "exposure", 0)
                    wait(500)
                    verify(pill.height > h)
                    pill.surface = ""
                    tryCompare(body, "exposure", 1, 2500)
                    // A stored file buds a droplet under the pill and is absorbed when hidden.
                    compare(body.shader.drop0.w, 0)
                    body.dock = Qt.vector3d(body.shader.pillCx + 40, body.shader.pillCy + body.shader.pillHalfH + 21, 13)
                    body.docked = true
                    tryCompare(body, "dockProgress", 1, 2000)
                    compare(body.shader.drop0.w, 1)
                    fuzzyCompare(body.shader.drop0.y, body.dock.y, 0.01)
                    fuzzyCompare(body.shader.drop0.z, 13, 0.01)
                    body.docked = false
                    tryCompare(body.shader.drop0, "w", 0, 2000)
                    pill.fluidJoined = true
                    tryCompare(body, "exposure", 0)
                    pill.fluidJoined = false
                    tryCompare(body, "exposure", 1)
                    pill.layoutChanging = true
                    tryCompare(body, "exposure", 0)
                    pill.layoutChanging = false
                    pill.restHeight = 56; pill.restLeftWidth = 80; pill.restRightWidth = 90; pill.s = 1.5
                    tryCompare(body, "exposure", 1, 3000)
                    compare(body.height, 84)
                    compare(body.shader.designScale, 1.5)
                    compare(body.width, pill.width)
                    pill.opacity = 0
                    tryCompare(body, "exposure", 0)
                    verify(!body.engine.active)
                    verify(!pill.bodyAudioWanted)
                    pill.opacity = 1
                    tryCompare(body, "exposure", 1)
                    Config.update({appearance: {reduceMotion: true}})
                    tryCompare(body, "reduceMotion", true)
                    verify(!body.engine.frameRunning && !body.engine.timerRunning)
                    pill.visible = false
                    compare(body.exposure, 0)
                    verify(!body.engine.active)
                    pill.visible = true
                    Config.update({appearance: {reduceTransparency: true}})
                    compare(body.exposure, 0); compare(material.opacity, 1)
                    Config.update({appearance: {reduceTransparency: false, personality: false}})
                    compare(body.exposure, 0)
                    passed = true
                    console.info("PASS: BodyPill geometry, handoff, interruption, surface, Fluid, hidden and accessibility")
                } catch (error) {
                    console.error("FAIL: BodyPill " + error + " " + error.stack)
                    throw error
                } finally { finished = true }
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
    }
}
