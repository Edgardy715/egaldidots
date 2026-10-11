import QtQuick
import Quickshell
import "Singletons"
import "components"
import "surfaces"

ShellRoot {
    Item {
        width: 1920; height: 1080
        Item { id: body; x: 913; y: 8; width: 94; height: 38 }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: body
            centered: true
            surfaceName: "settings"
            surfaceSize: IslandGeometry.settingsSurface
            retainExpandedContent: true
            expandedContent: Component {
                SettingsSurface {
                    open: drop.open || (drop.active && drop.cardContentProgress > 0.01)
                    closing: !drop.open
                    morphCloseness: drop.cardContentProgress
                }
            }
        }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    Timer {
        interval: 30; running: true
        onTriggered: {
            Config.update({ appearance: { reduceMotion: false } })
            drop.expanded = true
            drop.open = true
            drop.start()
            for (let i = 0; i < 200; i++) drop.advanceMotion(1 / 60)
            check(Math.abs(drop.visualX - 460) < 1 && Math.abs(drop.yPos - 190) < 1,
                "settings card centered")
            check(drop.surfaceItem !== null, "settings content mounted")
            const retained = drop.surfaceItem
            const editor = retained.children.find(child => typeof child.showProfile === "function")
            check(!!editor, "settings editor available")
            editor.searchQuery = "fuente"
            retained.profileRequest++
            check(editor.page === 4 && editor.searchQuery === "", "avatar request opens unfiltered profile")
            editor.page = 0
            retained.profileRequest++
            check(editor.page === 4, "repeated avatar request returns to profile")
            drop.open = false
            check(retained.visible && retained.opacity > 0.5, "content remains at start of return")
            for (let i = 0; i < 20; i++) drop.advanceMotion(1 / 60)
            check(retained.opacity < 1, "content fades with returning geometry")
            for (let i = 0; i < 240 && drop.phase !== "idle"; i++) drop.advanceMotion(1 / 60)
            check(drop.phase === "idle" && drop.surfaceItem === retained, "content survives close")
            drop.open = true
            drop.start()
            check(drop.surfaceItem === retained, "content reused on reopen")
            Config.update({ appearance: { reduceMotion: true } })
            drop.close()
            check(drop.phase === "idle", "reduced motion closes")
            console.log("PASS: centered settings drop, persistent content, reopen and reduced motion")
            Qt.quit()
        }
    }
}
