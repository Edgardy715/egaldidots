pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "components"
import "pets"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        width: 760; height: 300
        visible: true
        color: Theme.background
        property int opens: 0
        property int selected: 0
        TopWorkspaceRail {
            id: split
            x: 60; y: 60
            petEnabled: true
            petPresented: true
            onRequestWorkspaces: window.opens++
            onWorkspaceRequested: id => window.selected = id
        }
        TopWorkspaceRail {
            id: compact
            x: 60; y: 160
            integrated: true
            petEnabled: true
            petPresented: true
        }
        Text { x: 440; y: 76; text: qsTr("Split · Mimo"); color: Theme.foreground; font.pixelSize: 18 }
        Text { x: 440; y: 176; text: qsTr("Compact · Mimo"); color: Theme.foreground; font.pixelSize: 18 }
        Timer { id: finish; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "EshellPets"
            when: Config.loaded && window.visible
            function check(condition, message) { if (!condition) throw new Error(message) }
            function shot(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir) return
                window.contentItem.grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
                wait(100)
            }
            function test_lifecycleAndInput() {
                try {
                    Config.update({appearance: {reduceMotion: false}})
                    wait(300)
                    const host = findChild(split, "workspacePetHost")
                    const smallHost = findChild(compact, "workspacePetHost")
                    const hit = findChild(split, "workspaceNavigationHit")
                    check(host && host.item && smallHost.item, "ghost loads in both layouts")
                    check(!host.enabled && !host.activeFocusOnTab, "pet adds no input target")
                    check(host.item.runtime.petState === "idle", "no startup reaction")
                    const width = split.width
                    shot("rest")
                    mouseClick(hit, hit.width / 2, hit.height / 2)
                    check(window.opens === 1, "existing navigation click remains available")
                    hit.forceActiveFocus()
                    keyClick(Qt.Key_Return)
                    check(window.opens === 2, "keyboard activation remains available")
                    hit.focus = false
                    mouseMove(window.contentItem, 720, 260)
                    wait(700)
                    split.activeId = 5
                    wait(45)
                    check(host.item.runtime.reacting, "workspace signal starts finite reaction")
                    shot("reaction")
                    for (let i = 0; i < 8; i++) { split.activeId = i % 5 + 1; wait(18) }
                    split.activeId = 3
                    wait(700)
                    check(!host.item.runtime.reacting && host.item.runtime.impulse === 0, "burst settles at latest workspace")
                    check(host.item.runtime.lookX > 0 && host.item.runtime.workspaceId === 3, "gaze follows actual destination")
                    check(split.width === width, "pet never reserves layout space")
                    const mark = findChild(split, "workspaceMark-2")
                    mouseClick(split, mark.parent.x + mark.parent.width / 2 + split.navWidth + split.inset, split.height / 2)
                    check(window.selected === 2, "workspace clicks pass through unchanged")
                    split.activeId = 4
                    Config.update({appearance: {reduceMotion: true}})
                    wait(20)
                    check(host.item.runtime.impulse === 0 && !host.item.runtime.reacting && host.item.runtime.lookX === 0, "reduced motion settles immediately")
                    shot("reduced")
                    Config.update({appearance: {reduceMotion: false}})
                    split.petProfile = "minimal"
                    split.activeId = 1
                    check(!host.item.runtime.reacting, "minimal has no animated reaction")
                    split.petProfile = "playful"
                    split.petReactions = false
                    split.activeId = 2
                    check(!host.item.runtime.reacting, "behavior opt-out")
                    split.petReactions = true
                    split.activeId = 4
                    check(host.item.runtime.reacting, "reaction reenabled")
                    split.petPresented = false
                    check(!host.item && !host.active, "context withdrawal releases runtime and visual")
                    split.petPresented = true
                    wait(50)
                    check(host.item && host.item.runtime.impulse === 0, "reopening does not replay old events")
                    split.visible = false
                    check(!host.item, "hidden ancestor unloads pet")
                    split.visible = true
                    split.availableWidth = 20
                    check(!host.item, "rail without space unloads pet")
                    split.availableWidth = 360
                    split.petSize = 48
                    check(!host.item, "oversized character cannot obscure control")
                    shot("size-fallback")
                    split.petSize = 16
                    compact.petSize = 16
                    wait(50)
                    check(host.item && smallHost.item, "small size works in both hosts")
                    shot("size-16")
                    split.petSize = 32
                    compact.petSize = 32
                    wait(50)
                    check(host.item && !smallHost.item, "each host enforces its own safe region")
                    shot("size-32")
                    split.petSize = 24
                    compact.petSize = 24
                    split.s = 1.5
                    compact.s = 1.5
                    wait(700)
                    check(host.item && smallHost.item && host.fits && smallHost.fits, "logical scaling keeps pet in safe region")
                    shot("scale-150")
                    split.petProfile = "balanced"
                    host.item.runtime.sleepDelay = 120
                    wait(200)
                    check(host.item.runtime.petState === "sleeping" && host.item.runtime.breathing, "inactivity starts a finite sleep gesture")
                    shot("sleep-entry")
                    wait(450)
                    check(host.item.runtime.breath > 0, "sleep breathing has visible amplitude")
                    const breathBeforeWake = host.item.runtime.breath
                    host.item.runtime.sleepDelay = 45000
                    split.activeId = 1
                    check(!host.item.runtime.sleeping && host.item.runtime.reacting, "workspace activity wakes pet")
                    check(host.item.runtime.breath === breathBeforeWake, "wake keeps current breathing pose")
                    shot("wake")
                    wait(700)
                    check(host.item.runtime.breath === 0 && !host.item.runtime.breathing, "wake finishes residual breathing")
                    host.item.runtime.sleepDelay = 120
                    wait(200)
                    mouseMove(hit, hit.width / 2, hit.height / 2)
                    check(!host.item.runtime.sleeping && host.item.runtime.engaged, "existing control hover wakes pet")
                    wait(250)
                    check(!host.item.runtime.sleeping, "pet does not sleep while engaged")
                    mouseMove(window.contentItem, 720, 260)
                    wait(7600)
                    check(host.item.runtime.sleeping && !host.item.runtime.breathing && host.item.runtime.breath === 0,
                        "two breaths finish with no recurring sleep animation")
                    shot("sleep-settled")
                    split.activeId = 2
                    wait(200)
                    Config.update({appearance: {reduceMotion: true}})
                    check(host.item.runtime.sleeping && !host.item.runtime.breathing && host.item.runtime.breath === 0,
                        "reduced motion cancels sleep breathing without waking")
                    shot("sleep-reduced")
                    Config.update({appearance: {reduceMotion: false}})
                    split.petProfile = "minimal"
                    split.activeId = 3
                    wait(200)
                    check(host.item.runtime.sleeping && !host.item.runtime.breathing, "minimal sleep is a static expression")
                    split.petPresented = false
                    check(!host.item, "sleeping pet releases timer and animations when hidden")
                    split.petPresented = true
                    wait(50)
                    check(host.item && !host.item.runtime.sleeping, "new host never replays an old sleep episode")
                    split.petEnabled = false
                    check(host.item === null, "disabled feature releases all pet resources")
                    console.log("PASS: pets layouts, input, geometry, bursts, reduced, profiles, visibility, unload, scale and finite sleep/wake")
                    finish.start()
                } catch (error) { console.error("FAIL: pets " + error); Qt.exit(1) }
            }
        }
    }
}
