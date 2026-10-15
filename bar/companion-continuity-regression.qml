import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Item {
        width: 1920; height: 1080
        Item { id: body; x: 900; y: 8; width: 120; height: 38 }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: body
            expandedContent: Component { Item {} }
        }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: companion continuity", message); Qt.exit(1); throw new Error(message) }
    }
    Timer {
        interval: 50; running: true
        onTriggered: {
            Config.update({appearance: {reduceMotion: false}})
            for (const phase of ["media", "separando", "retornando"]) {
                drop.phase = phase
                const expected = drop.spring(100, -200, 800, 0.2)
                for (const fps of [30, 60, 144, 240]) {
                    let value = 100, velocity = -200, time = 0
                    while (time < 0.2 - 1e-9) {
                        const dt = Math.min(1 / fps, 0.2 - time)
                        const next = drop.spring(value, velocity, 800, dt)
                        value = next[0]; velocity = next[1]; time += dt
                    }
                    check(Math.abs(value - expected[0]) < 1e-7
                        && Math.abs(velocity - expected[1]) < 1e-7, phase + " refresh independence " + fps)
                }
                let next = [100, -200]
                for (let i = 0; i < 8; i++) next = drop.spring(next[0], next[1], 800, 0.01)
                const stalled = drop.spring(100, -200, 800, 0.08)
                check(Math.abs(next[0] - stalled[0]) < 1e-7
                    && Math.abs(next[1] - stalled[1]) < 1e-7, phase + " preserves elapsed time after stall")
            }
            drop.phase = "companion"
            drop.wPos = 38; drop.hPos = 38; drop.yPos = body.y
            let previousWaist = 0.42
            for (let i = 0; i <= 28; i++) {
                const stretch = 1.02 + i * 0.01
                drop.xPos = drop.capX + stretch * (drop.bodyRadius + drop.dropRadius) - drop.wPos / 2
                check(drop.neckWaist <= previousWaist + 1e-9 && drop.neckWaist >= 0, "neck contracts monotonically")
                previousWaist = drop.neckWaist
            }
            check(drop.neckWaist < 1e-9, "neck reaches zero before bond breaks")
            drop.phase = "retornando"; drop.bond = false
            let previousEdge = 1
            for (let i = 0; i <= 30; i++) {
                const stretch = 1.31 - i * 0.01
                drop.xPos = drop.capX + stretch * (drop.bodyRadius + drop.dropRadius) - drop.wPos / 2
                drop.updateBond()
                check(drop.edgeExposure <= previousEdge + 1e-9
                    && previousEdge - drop.edgeExposure < 0.06, "return neck and edge join continuously")
                previousEdge = drop.edgeExposure
            }
            drop.captureExtra = 20; drop.wPos = 38; drop.hPos = 38
            drop.xPos = body.x + body.width + 20 - 38 + 0.2
            check(!drop.coveredByBody, "visible tip cannot be concealed")
            drop.xPos -= 0.4
            check(drop.coveredByBody, "capsule contains compact drop behind receiving cap")
            drop.wPos = drop.collapsedW; drop.hPos = drop.cardH
            check(drop.cardContentProgress === 0, "card content requires width as well as height")
            for (let i = 0; i <= 100; i++) {
                const fraction = i / 100
                drop.wPos = drop.moduleH + (drop.cardW - drop.moduleH) * fraction
                drop.hPos = drop.moduleH + (drop.cardH - drop.moduleH) * fraction
                check(drop.cardRadius <= 24 * drop.s
                    && drop.cardRadius <= Math.min(drop.wPos, drop.hPos) / 2,
                    "contraction never inflates card corners")
            }
            drop.wPos = drop.collapsedW + (drop.cardW - drop.collapsedW) * 0.4
            drop.hPos = drop.moduleH + (drop.cardH - drop.moduleH) * 0.4
            check(drop.cardContentProgress > 0.5, "scaled editor stays visible during contraction")
            drop.phase = "media"
            drop.xPos = drop.targetX; drop.yPos = drop.targetY
            drop.wPos = drop.targetW; drop.hPos = drop.targetH
            drop.captureExtra = drop.captureTarget
            drop.vx = 200
            check(!drop.settled, "crossing the target with velocity is not rest")
            drop.open = true
            drop.expanded = true
            drop.start()
            for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
            drop.open = false
            for (let i = 0; i < 240 && drop.phase !== "absorbiendo"; i++) drop.advanceMotion(1 / 60)
            check(drop.phase === "absorbiendo", "return reaches capture")
            const x = drop.xPos, y = drop.yPos, w = drop.wPos
            const vx = drop.vx, vy = drop.vy, vw = drop.vw, cap = drop.captureExtra
            drop.open = true
            check(drop.xPos === x && drop.yPos === y && drop.wPos === w
                && drop.vx === vx && drop.vy === vy && drop.vw === vw
                && drop.captureExtra === cap && !drop.concealed,
                "reopen during capture preserves presentation and velocity")
            for (let i = 0; i < 12; i++) drop.advanceMotion(1 / 60)
            Config.update({appearance: {reduceMotion: true}})
            check(drop.phase === "media" && drop.settled && !drop.bond && drop.captureExtra === 0,
                "enable reduced motion during expansion resolves geometry")
            Config.update({appearance: {reduceMotion: false}})
            drop.open = false
            for (let i = 0; i < 6; i++) drop.advanceMotion(1 / 60)
            Config.update({appearance: {reduceMotion: true}})
            check(drop.phase === "idle" && !drop.active && drop.captureExtra === 0,
                "enable reduced motion during return resolves idle")
            console.log("PASS: companion refresh independence, 80ms stall, velocity at target, capture reopen, geometric neck pinch and live reduced motion")
            Qt.quit()
        }
    }
}
