import QtQuick
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    Item {
        width: 1920; height: 1080
        Item { id: body; x: 900; y: 8; width: 94; height: 38 }
        FluidCompanion {
            id: drop; anchors.fill: parent; body: body
            leftSide: true; surfaceName: "session"; surfaceSize: IslandGeometry.sessionSurface
        }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    Timer {
        interval: 30; running: true
        onTriggered: {
            Config.update({ appearance: { reduceMotion: false } })
            drop.expanded = true
            drop.start()
            for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
            check(drop.visualX + drop.wPos <= body.x - 11, "card left of pill")
            check(Math.abs(drop.wPos - 540) < 1 && Math.abs(drop.hPos - 304) < 1, "session geometry")
            check(drop.cardContentProgress === 1, "full content revealed")
            drop.close()
            for (let i = 0; i < 8; i++) drop.advanceMotion(1 / 60)
            const x = drop.xPos, vx = drop.vx
            drop.retarget("media", drop.cardX, drop.cardY, drop.cardW, drop.cardH)
            check(drop.xPos === x && drop.vx === vx, "interruption preserves velocity")
            for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
            drop.close()
            body.x = 780; body.y = 200; body.width = 200
            for (let i = 0; i < 240 && drop.phase !== "idle"; i++) drop.advanceMotion(1 / 60)
            check(drop.phase === "idle" && !drop.active && drop.captureExtra < 0.1, "fully absorbed")
            Config.update({ appearance: { reduceMotion: true } })
            drop.start(); drop.close()
            check(drop.phase === "idle" && !drop.active, "reduced motion")
            console.log("PASS: left session geometry, reveal, interruption, absorption and reduced motion")
            Qt.quit()
        }
    }
}
