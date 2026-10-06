import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 1000; height: 110
        color: "#242424"
        TopBarModules {
            id: modules
            anchors.fill: parent
            screenName: "modules-test"
        }
        SignalSpy { id: requests; target: modules; signalName: "requestSurface" }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "OptionalModules"
            when: scene.visible
            property bool finished: false
            function check(ok, message) {
                if (!ok) { console.error("FAIL:", message); throw new Error(message) }
            }
            function shot(name) {
                const dir = Quickshell.env("ISLA_MODULE_SHOTS")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }
            function patch(value) { check(Config.update(value).ok, "configuration patch accepted") }
            function test_lifecycle() {
                tryVerify(() => Config.loaded)
                patch({appearance: {reduceMotion: false}, modules: {workspaceRail: true, systemStatus: true,
                    apps: true, audio: true, network: true, battery: true, animateChanges: true}})
                wait(65)
                check(modules.statusItem.width >= modules.statusItem.controlsWidth + 22 * modules.s, "controls reveal inside full startup glass")
                wait(585)
                const left = modules.workspaceModule
                const right = modules.statusModule
                check(left.status === Loader.Ready && right.status === Loader.Ready, "both modules load")
                check(left.exposure === 1 && right.exposure === 1, "both modules reveal")
                shot("shown")
                patch({modules: {workspaceRail: false, systemStatus: false}})
                check(!left.interactive && !right.interactive, "exit releases input immediately")
                wait(65)
                check(left.item && left.exposure > 0 && left.exposure < 1, "content retained during animated exit")
                shot("exiting")
                patch({modules: {workspaceRail: true, systemStatus: true}})
                wait(65)
                shot("reversed")
                wait(650)
                check(left.exposure === 1 && left.active, "interrupted exit returns to shown " + left.exposure + "/" + left.active + "/" + left.interactive)
                patch({modules: {workspaceRail: false, systemStatus: false}})
                wait(650)
                check(!left.active && !left.item && !right.active && !right.item, "disabled modules unload")
                shot("unloaded")
                patch({modules: {systemStatus: true}})
                wait(650)
                const status = right.item
                status.windows = [{lastIpcObject: {class: "kitty"}}, {lastIpcObject: {class: "firefox"}}]
                wait(650)
                const audio = findChild(status, "statusAudioModule")
                mouseClick(audio.item, audio.item.width / 2, audio.item.height / 2)
                check(requests.count === 1 && requests.signalArguments[0][0] === "mixer", "audio action reaches composition")
                const initialWidth = status.width
                patch({modules: {apps: false, audio: false, network: true, battery: false}})
                wait(650)
                check(status.width < initialWidth && status.width > 0, "individual controls contract the container")
                check(!findChild(status, "statusApps"), "disabled apps unload")
                shot("network-only")
                modules.availableWidth = 90
                wait(250)
                check(right.visible && right.interactive && status.width <= 90, "single control fits narrow monitor")
                modules.availableWidth = 360
                patch({modules: {audio: true}})
                wait(65)
                check(audio.exposure === 0 || audio.parent.x + audio.x >= 9 * modules.s,
                    "new control waits for available glass")
                wait(600)
                check(audio.interactive && audio.exposure === 1, "new audio control reveals after expansion")
                patch({modules: {apps: false, audio: false, network: false, battery: false}})
                wait(650)
                check(!right.active && !right.item, "empty status container unloads")
                patch({modules: {workspaceRail: true, animateChanges: false}})
                wait(40)
                check(left.exposure === 1, "animation preference resolves entrance " + left.exposure + "/" + left.status + "/" + left.presented + "/" + left.animateChanges)
                patch({modules: {workspaceRail: false}})
                wait(40)
                check(!left.active && !left.item, "animation preference resolves exit")
                patch({modules: {workspaceRail: true, animateChanges: true}})
                wait(650)
                modules.presented = false
                wait(650)
                check(left.active && left.item && !left.visible, "temporary hiding retains enabled module")
                modules.presented = true
                wait(650)
                patch({modules: {workspaceRail: false}})
                wait(50)
                patch({appearance: {reduceMotion: true}})
                wait(40)
                check(!left.active && !left.item, "reduce motion during exit immediately unloads")
                patch({modules: {workspaceRail: true}})
                wait(40)
                check(left.exposure === 1, "reduce motion entrance resolves immediately")
                modules.availableWidth = 90
                wait(40)
                check(!left.visible && !left.interactive, "narrow monitor hides workspace module")
                console.log("PASS: optional module settings, lifetime, exit, reversal, input, controls, temporary hide and reduced motion")
                finished = true
            }
        }
    }
}
