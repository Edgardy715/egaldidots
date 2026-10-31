import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Item {
        width: 2560; height: 1440
        Item { id: body; x: 1180; y: 8; width: 200; height: 38 }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: body
            centered: true
            below: true
            springRate: 1.5
            surfaceSize: Qt.size(380, 72)
            expandedContent: Component { Item {} }
        }
        FluidCompanion {
            id: plain
            anchors.fill: parent
            body: body
            centered: true
            surfaceSize: Qt.size(380, 72)
            expandedContent: Component { Item {} }
        }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: notification drop", message); Qt.exit(1); throw new Error(message) }
    }
    Timer {
        interval: 50; running: true
        onTriggered: {
            Config.update({appearance: {reduceMotion: false}})
            check(Flags.notificationDrop, "drop is on by default")
            check(Math.abs(drop.cardY - (body.y + body.height + drop.gap)) < 1e-6, "card rests one gap under the body")
            check(Math.abs(plain.cardY - (plain.height - plain.cardH) / 2) < 1e-6, "settings placement unchanged without below")
            check(Math.abs(drop.capY - (body.y + body.height - drop.capRadius)) < 1e-6, "bud leaves from the lower edge")
            drop.expanded = true
            drop.start()
            check(drop.phase === "brotando", "buds instead of growing in place")
            check(drop.yPos < body.y + body.height, "the drop is born inside the pill's lower edge")
            let t = 0, legible = -1
            for (let i = 0; i < 144 && legible < 0; i++) {
                drop.advanceMotion(1 / 144); t += 1 / 144
                const scale = Math.min(drop.wPos / drop.cardW, drop.hPos / drop.cardH)
                if (drop.cardContentProgress >= 0.9 && scale >= 0.85) legible = t
            }
            check(legible > 0 && legible <= 0.25, "title legible within 250 ms (" + Math.round(legible * 1000) + " ms)")
            for (let i = 0; i < 144; i++) drop.advanceMotion(1 / 144)
            check(drop.phase === "media" && Math.abs(drop.hPos - drop.cardH) < 0.5, "card settles at its size")
            drop.expanded = false; drop.open = false
            drop.close()
            let frames = 0
            while (drop.phase !== "idle" && frames++ < 600) drop.advanceMotion(1 / 144)
            check(drop.phase === "idle", "drop gathers back into the pill")
            console.log("PASS: notification drop geometry, legible in", Math.round(legible * 1000), "ms and return")
            Qt.exit(0)
        }
    }
}
