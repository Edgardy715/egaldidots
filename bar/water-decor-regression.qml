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
        width: 1000; height: 800
        Pill {
            id: pill
            x: 200; y: 100
            notificationsEnabled: false
        }
        Item {
            x: 10; y: 600; width: 300; height: 160
            PillMaterial {
                id: wrapper
                shaderActive: true
                surface: "media"
                artUrl: Qt.resolvedUrl("tests/fixtures/artwork-blue.svg")
                materialAwake: true
                materialPulse: .5
                notifBreathGlow: .1
            }
        }
        Item { id: origin; x: 300; y: 200; width: 120; height: 38 }
        QtObject {
            id: available
            property bool waterActive: true
            property bool messengerActive: false
            property var received: null
            function receive(position, companion) { received = companion }
        }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: origin
            waterBody: available
            manualStep: true
            expandedContent: Component { Item {} }
            retainExpandedContent: true
            artUrl: Qt.resolvedUrl("tests/fixtures/artwork-blue.svg")
        }
        PillBody {
            id: probe
            width: 160; height: 38
            liveHeight: 160
            waterBody: true
            surface: "media"
            artUrl: Qt.resolvedUrl("tests/fixtures/artwork-blue.svg")
        }
        TestCase {
            id: checks
            name: "WaterDecor"
            when: scene.visible
            property bool passed: false
            property bool finished: false
            function test_decor() {
                try {
                    tryVerify(() => Config.loaded, 2000)
                    Config.update({appearance: {waterBody: true, personality: false, liquidSurfaces: false,
                        reduceMotion: false, reduceTransparency: false}})
                    const loader = findChild(wrapper, "pillMaterialDecorations")
                    verify(!loader.active && loader.item === null)
                    for (const name of ["pillMaterialHalo", "mediaAmbient", "pillMaterialInnerGlow", "pillMaterialAccentTop", "pillMaterialAccentTint"])
                        verify(!findChild(wrapper, name), "no duplicate " + name)
                    wrapper.receive(.55)
                    verify(!wrapper.receiving)
                    wrapper.shaderActive = false
                    verify(loader.active && loader.item !== null)
                    verify(findChild(wrapper, "mediaAmbient"))
                    wrapper.receive(.55)
                    verify(wrapper.receiving)
                    wrapper.settleReception()
                    verify(!wrapper.receiving)
                    wrapper.shaderActive = true
                    verify(loader.item === null)
                    drop.open = true; drop.expanded = true; wait(1)
                    for (let i = 0; i < 800; ++i) drop.advanceMotion(1 / 240)
                    drop.receive()
                    compare(available.received, drop, "feedback is wired to the shared body")
                    verify(!findChild(drop, "companionLegacyMaterial"))
                    // Deterministic spring continuity, also on software without claiming shader execution.
                    probe.receptionMotion.active = true
                    probe.sweepMotion.active = true
                    compare(probe.receptionMotion.spring, Motion.strokeSpring.wave)
                    compare(probe.sweepMotion.spring, Motion.strokeSpring.tide)
                    verify(probe.receptionMotion.manualStep && probe.sweepMotion.manualStep)
                    probe.receptionMotion.kick(Motion.strokeSpring.wave.omega)
                    probe.sweepMotion.target = 1
                    probe.shader.advanceDecor(.04)
                    verify(probe.receptionMotion.value > 0)
                    const value = probe.sweepMotion.value, velocity = probe.sweepMotion.velocity
                    probe.sweepMotion.target = 2
                    compare(probe.sweepMotion.value, value); compare(probe.sweepMotion.velocity, velocity)
                    const wave = probe.receptionMotion.value
                    probe.receptionMotion.kick(Motion.strokeSpring.wave.omega)
                    compare(probe.receptionMotion.value, wave, "repeated reception does not reset position")
                    for (let i = 0; i < 1600; ++i) probe.shader.advanceDecor(1 / 240)
                    verify(!probe.receptionMotion.integrating && !probe.sweepMotion.integrating)
                    verify(!probe.shader.layer.enabled && !probe.shader.settling)
                    compare(probe.shader.artBox.z, probe.width / 2)
                    probe.surface = ""
                    probe.companion0 = drop
                    compare(probe.ambientUrl, drop.artUrl)
                    compare(probe.ambientBox, drop.fieldBox)
                    drop.expanded = false
                    compare(probe.ambientUrl, drop.artUrl, "outgoing media retains its ambient artwork")
                    drop.expanded = true
                    compare(probe.ambientUrl, drop.artUrl, "reversal retains artwork")
                    probe.companion0 = null
                    compare(probe.ambientUrl, "")
                    const body = findChild(pill, "pillBody")
                    const material = findChild(pill, "pillMaterial")
                    if (body.shaderSupported) {
                        tryVerify(() => body.waterActive, 2000)
                        pill.respond("received")
                        verify(body.receiving && !material.receiving)
                        tryVerify(() => !body.receiving && !body.sweepMotion.integrating && !body.shader.settling, 5000)
                        verify(!body.shader.decorMoving && !body.shader.layer.enabled)
                        probe.surface = "media"
                        tryVerify(() => probe.shader.artReady > .5, 3000)
                        waitForRendering(probe.shader)
                        const before = grabImage(probe.shader)
                        probe.artUrl = Qt.resolvedUrl("tests/fixtures/artwork-coral.svg")
                        tryVerify(() => probe.shader.artFirstUrl.endsWith("artwork-coral.svg"), 2000)
                        tryVerify(() => probe.shader.artReady > .5, 3000)
                        wait(100); waitForRendering(probe.shader)
                        const after = grabImage(probe.shader)
                        verify(!before.equals(after), "art changes the field pixels")
                        body.shader.fragmentShader = Qt.resolvedUrl("body/shaders/w4-missing.frag.qsb")
                        tryCompare(body.shader, "status", ShaderEffect.Error, 3000)
                        verify(!body.waterActive && !material.shaderActive)
                        verify(findChild(material, "pillMaterialDecorations").item !== null)
                    } else console.info("WaterDecor RHI art pixels / actual shader error: NOT VERIFIED")
                    Config.update({appearance: {reduceMotion: true}})
                    verify(!body.waterActive && !material.shaderActive)
                    verify(!body.receptionMotion.integrating && !body.sweepMotion.integrating && !body.shader.settling)
                    verify(findChild(material, "pillMaterialDecorations").item !== null)
                    Config.update({appearance: {reduceMotion: false, waterBody: false}})
                    verify(!body.waterActive && !material.shaderActive)
                    console.info("PASS: WaterDecor no duplicate instances, fallback, artwork routing, named interruptible springs, quiet/reduced motion")
                    passed = true
                } catch (error) {
                    console.error("FAIL: WaterDecor " + error + " " + error.stack)
                    throw error
                } finally { finished = true }
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
    }
}
