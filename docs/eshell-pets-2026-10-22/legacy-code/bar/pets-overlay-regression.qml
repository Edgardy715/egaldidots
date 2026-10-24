import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "windows"
import "Singletons"

ShellRoot {
    id: root
    property bool captureOk: false
    settings.watchFiles: false
    Process {
        id: compositorGrab
        onExited: (exitCode, exitStatus) => { root.captureOk = exitCode === 0 }
    }
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    Timer { id: finish; interval: 120; onTriggered: Qt.quit() }
    TestCase {
        name: "PetsOverlay"
        when: Config.loaded
        function check(condition, message) { if (!condition) throw new Error(message) }
        function until(predicate, message) {
            for (let i = 0; i < 250 && !predicate(); i++) wait(20)
            check(predicate(), message)
        }
        function shot(name) {
            const dir = Quickshell.env("ISLA_TEST_OUTPUT")
            if (!dir) return
            const content = findChild(overlay.contentItem, "islandOverlayContent")
            content.grabToImage(result => result.saveToFile(dir + "/overlay-" + name + ".png"))
            wait(100)
            const geometry = Quickshell.env("ISLA_PET_COMPOSITOR_GEOMETRY")
            if (geometry) {
                root.captureOk = false
                compositorGrab.command = ["grim", "-g", geometry, dir + "/compositor-" + name + ".png"]
                compositorGrab.running = true
                until(() => !compositorGrab.running, "compositor capture terminates")
                check(root.captureOk, "compositor capture succeeds")
            }
        }
        function test_composition() {
            try {
                Config.update({appearance: {reduceMotion: true, personality: true}, modules: {
                    workspaceRail: true, systemStatus: false, userAvatar: false}, pets: {enabled: false}})
                const modules = findChild(overlay.contentItem, "islandModules")
                const pill = findChild(overlay.contentItem, "islandPill")
                check(modules && pill, "production composition loads")
                until(() => modules.workspaceItem !== null, "workspace module loads")
                const eyes = findChild(pill, "activityCompanion")
                check(eyes && eyes.visible && !modules.petVisible, "default preserves original expression")
                Config.update({pets: {enabled: true}})
                until(() => modules.petVisible, "focused monitor presents pet")
                check(pill.petVisible && !eyes.visible, "one visible companion in pill composition")
                shot("split")
                if (Quickshell.env("ISLA_PET_MOTION_CAPTURE") === "1") {
                    Config.update({appearance: {reduceMotion: false}})
                    const rail = modules.workspaceItem
                    const pet = findChild(rail, "workspacePetHost")
                    const started = Date.now()
                    pet.item.runtime.sleep()
                    for (let frame = 0; frame < 36; frame++) {
                        if (frame === 12) rail.activeId = rail.activeId === 1 ? 2 : 1
                        if (frame === 19) pet.item.runtime.sleep()
                        wait(130)
                        shot("motion-" + String(frame).padStart(3, "0"))
                        console.log("PET_VISUAL_FRAME " + JSON.stringify({frame: frame, elapsedMs: Date.now() - started,
                            state: pet.item.runtime.petState, breath: pet.item.runtime.breath}))
                    }
                    Config.update({appearance: {reduceMotion: true}})
                }
                router.focusedMonitorName = "another-monitor"
                check(!modules.petVisible && !pill.petVisible, "focus transfer releases pet on previous monitor")
                router.focusedMonitorName = Quickshell.screens[0].name
                until(() => modules.petVisible, "focus return reacquires pet")
                Config.update({appearance: {barLayout: "compact"}})
                until(() => overlay.compact && !overlay.layoutChanging && modules.petVisible, "compact transition preserves pet host")
                check(!eyes.visible && modules.contentFits, "compact stays within actual content budget")
                shot("compact")
                Config.update({pets: {size: 48}})
                until(() => !modules.petVisible, "oversized pet falls back")
                check(eyes.visible, "fallback restores original expression")
                Config.update({pets: {size: 24}})
                until(() => modules.petVisible, "pet size restores")
                Config.update({modules: {workspaceRail: false}})
                until(() => !modules.petVisible && !modules.workspaceModule.item, "disabled rail releases pet")
                Config.update({modules: {workspaceRail: true}, appearance: {reduceMotion: false, barLayout: "split"}})
                until(() => !overlay.compact && !overlay.layoutChanging && modules.petVisible, "animated return acquires pet only after layout settles")
                Config.update({pets: {enabled: false}})
                until(() => !modules.petVisible, "config opt-out releases pet")
                check(Config.appearance.personality && eyes.visible, "pet opt-out preserves personality setting")
                console.log("PASS: pets production composition, monitor arbitration, layout, settings and legacy expression")
                finish.start()
            } catch (error) { console.error("FAIL: pets overlay " + error); Qt.exit(1) }
        }
    }
}
