import QtQuick
import QtTest
import Quickshell
import "components"
import "settings"
import "Singletons"

ShellRoot {
    id: test
    readonly property var styles: ["numbers", "dots", "bars", "capsules", "pacman"]
    property int step: 0
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
    function find(item, name) { if (item.objectName === name) return item; for (const child of item.children) { const match = find(child, name); if (match) return match } return null }
    Window {
        id: window
        visible: true; width: 900; height: 650; color: Theme.background
        visibility: Window.FullScreen
        Column {
            id: samples
            x: 24; y: 24; spacing: 14
            Repeater {
                id: rows
                model: test.styles
                delegate: Row {
                    required property string modelData
                    spacing: 24
                    Text { width: 100; height: 48; verticalAlignment: Text.AlignVCenter; text: modelData; color: Theme.foreground }
                    TopWorkspaceRail { objectName: "split"; style: modelData; activeId: 2; occupied: ({1: {occupied: true}, 4: {occupied: true, urgent: true}}) }
                    TopWorkspaceRail { objectName: "compact"; style: modelData; integrated: true; activeId: 2; occupied: ({1: {occupied: true}, 4: {occupied: true, urgent: true}}) }
                }
            }
        }
        SettingsPage { id: settings; x: 24; y: 370; width: parent.width - 48; height: 220; config: Config; fieldKeys: ["appearance.workspaceStyle"] }
    }
    TestCase { id: input; when: false; function test_input() {} }
    Timer {
        interval: 160; running: true; repeat: true
        onTriggered: {
            if (test.step < 5) {
                const style = test.styles[test.step]
                const choice = test.find(settings, "choice-" + style)
                test.check(choice !== null, "setting choice exists: " + style)
                input.mouseClick(choice, choice.width / 2, choice.height / 2)
                test.check(Config.appearance.workspaceStyle === style, "native choice applies: " + style)
                for (const candidate of test.styles) test.check(test.find(settings, "choice-" + candidate).checked === (candidate === style), "only current choice selected: " + candidate)
                for (let i = 0; i < rows.count; i++) {
                    const row = rows.itemAt(i)
                    for (const name of ["split", "compact"]) {
                        const rail = test.find(row, name)
                        test.check(rail.width <= rail.availableWidth, "rail fits: " + rail.style)
                        rail.activeId = test.step + 1
                    }
                }
            } else if (test.step === 5) {
                test.check(!Config.update({appearance: {workspaceStyle: "invalid"}}).ok, "unknown style rejected")
                Config.discard()
                test.check(Config.appearance.workspaceStyle === "numbers", "discard restores default")
                test.check(Config.update({appearance: {workspaceStyle: "capsules"}}).ok && Config.save(), "save style to isolated file")
            } else if (test.step === 8) {
                test.check(!Config.saving && !Config.dirty && Config.error === "", "isolated save completes")
                Config.reload()
            } else if (test.step === 9) {
                test.check(Config.appearance.workspaceStyle === "capsules", "saved style survives reload")
                const directory = Quickshell.env("ISLA_WORKSPACE_CAPTURE_DIR")
                if (directory) samples.grabToImage(result => result.saveToFile(directory + "/styles.png"))
            } else if (test.step === 12) {
                console.log("PASS: five workspace representations, both layouts, setting choices, validation and discard")
                Qt.quit()
            }
            test.step++
        }
    }
}
