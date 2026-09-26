import QtQuick
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    Item {
        width: 1920; height: 1080
        Item { id: body; x: 900; y: 8; width: 94; height: 38 }
        FluidMediaCompanion { id: drop; anchors.fill: parent; body: body; screenName: "absorption-test" }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    Timer {
        interval: 20; running: true
        onTriggered: {
            Config.update({ appearance: { reduceMotion: false } })
            for (const fps of [30, 60, 144]) {
                for (const width of [42, 76, 218, 640]) {
                    drop.phase = "companion"; drop.concealed = false
                    drop.xPos = body.x + body.width + 12
                    drop.yPos = body.y
                    drop.wPos = width; drop.hPos = width === 640 ? 300 : 38
                    drop.vx = 0; drop.vy = 0; drop.vw = 0; drop.vh = 0
                    drop.captureExtra = 0; drop.captureV = 0; drop.captureTarget = 0
                    drop.close()
                    let captured = false
                    for (let frame = 0; frame < fps * 4 && drop.phase !== "idle"; frame++) {
                        const wasReturning = drop.phase === "retornando"
                        drop.advanceMotion(Math.min(0.032, 1 / fps))
                        if (wasReturning && drop.phase === "absorbiendo") {
                            captured = true
                            check(drop.coveredByBody, "conceal only under cap")
                            check(Math.abs(drop.vx) + Math.abs(drop.vw) + Math.abs(drop.vh) > 0.2,
                                  "capture must not wait for stopped springs")
                            check(drop.contentExposure < 0.01, "content hidden before capture")
                        }
                    }
                    check(captured && drop.phase === "idle", "complete absorption " + fps + "/" + width)
                    check(drop.captureExtra < 0.1, "cap returns to rest")
                }
            }
            console.log("PASS: continuous capture at 30/60/144 Hz, compact/playing/hover/card, coverage and return")
            Qt.quit()
        }
    }
}
