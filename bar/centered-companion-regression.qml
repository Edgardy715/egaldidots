import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Item {
        width: 1920; height: 1080
        Item { id: body; x: (parent.width - width) / 2; y: 8; width: 100; height: 38 }
        FluidCompanion { id: drop; anchors.fill: parent; body: body; centered: true; expanded: true; expandedContent: Component { Item {} }
            surfaceName: "settings"; surfaceSize: IslandGeometry.settingsSurface }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL:", message); Qt.exit(1) } }
    Timer {
        interval: 50; running: true
        onTriggered: {
            Config.update({appearance: {reduceMotion: false}})
            for (const width of [100, 760]) {
                body.width = width
                body.height = width === 100 ? 38 : 56
                drop.start()
                check(Math.abs(drop.xPos + drop.wPos / 2 - (body.x + body.width / 2)) < 0.01, "birth at pill center")
                check(Math.abs(drop.capX - (body.x + body.width / 2)) < 0.01, "bridge uses centered origin")
                for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
                check(Math.abs(drop.xPos + drop.wPos / 2 - 960) < 0.1, "card centered horizontally")
                check(Math.abs(drop.yPos + drop.hPos / 2 - 540) < 0.1, "card centered vertically")
                drop.close()
                check(drop.targetW === drop.returnW && drop.targetH === drop.returnH
                    && drop.targetW >= body.width - body.height, "return lands as pill capsule instead of a ball")
                for (let i = 0; i < 10; i++) drop.advanceMotion(1 / 60)
                const x = drop.xPos, vx = drop.vx
                drop.retarget("media", drop.cardX, drop.cardY, drop.cardW, drop.cardH)
                check(drop.xPos === x && drop.vx === vx, "reopen preserves current position and velocity")
                for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
                drop.close()
                body.width = width === 100 ? 760 : 100
                body.height = width === 100 ? 56 : 38
                check(drop.targetW === drop.returnW && drop.targetH === drop.returnH, "return dimensions follow changing pill")
                for (let i = 0; i < 240 && drop.phase !== "idle"; i++) drop.advanceMotion(1 / 60)
                check(drop.phase === "idle" && !drop.active, "absorbed after body changes layout")
                check(drop.coveredByBody, "whole returning capsule fits receiving pill")
                check(drop.captureExtra === 0, "centered return never stretches right edge")
            }
            body.width = 1500
            body.height = 56
            drop.open = true
            drop.start()
            for (let i = 0; i < 150; i++) drop.advanceMotion(1 / 60)
            drop.open = false
            check(drop.targetW <= drop.cardW, "wide pill does not enlarge closing editor")
            for (let i = 0; i < 120 && !drop.joined; i++) drop.advanceMotion(1 / 60)
            check(drop.joined && !drop.concealed, "return reaches receiving neck before hiding")
            const before = [drop.xPos, drop.yPos, drop.wPos, drop.hPos, drop.vx, drop.vy, drop.vw, drop.vh]
            drop.open = true
            const after = [drop.xPos, drop.yPos, drop.wPos, drop.hPos, drop.vx, drop.vy, drop.vw, drop.vh]
            check(before.every((value, index) => value === after[index]) && !drop.concealed,
                "reopen at contact preserves shape and all velocities")
            drop.open = false
            for (let i = 0; i < 240 && drop.phase !== "idle"; i++) drop.advanceMotion(1 / 60)
            check(drop.phase === "idle" && drop.coveredByBody, "wide receiving pill finishes capture")
            Config.update({appearance: {reduceMotion: true}})
            drop.start(); drop.close()
            check(drop.phase === "idle", "reduced motion resolves centered return")
            console.log("PASS: centered settings birth/card/bridge/absorption, both rest widths, interrupted return and reduced motion")
            Qt.quit()
        }
    }
}
