import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    Window {
        id: window
        visible: true; width: 800; height: 620
        Rectangle { anchors.fill: parent; color: Theme.cardBot }
        SettingsPage {
            id: page
            anchors.fill: parent
            config: Config
            section: "profile"
            fieldKeys: ["profile.displayName"]
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ConfigDraftConflict"
            when: window.visible
            property bool finished: false
            property bool captureFinished: false

            function findType(item, typeName) {
                if (String(item).startsWith(typeName + "_")) return item
                for (const child of item.children || []) {
                    const found = findType(child, typeName)
                    if (found) return found
                }
                return null
            }
            function typeText(text) { for (const letter of text) keyClick(letter) }

            function test_external_change() {
                tryCompare(Config, "loaded", true)
                const editor = findType(page, "EdotsTextField")
                verify(editor !== null, "profile editor found")
                editor.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                typeText("Mi borrador")
                compare(editor.text, "Mi borrador")
                verify(page.hasDrafts)
                console.log("DRAFT_READY")

                for (let n = 0; n < 200 && Config.profile.displayName !== "Cambio externo"; n++) wait(20)
                compare(Config.profile.displayName, "Cambio externo", "external FileView reload")
                verify(page.conflicts["profile.displayName"], "conflict is visible")
                verify(page.validationError, "save is blocked")
                compare(editor.text, "Mi borrador", "draft text preserved")
                const captureDir = Quickshell.env("ISLA_DRAFT_CAPTURE_DIR") || ""
                if (captureDir) {
                    wait(150)
                    window.contentItem.grabToImage(result => {
                        console.log("DRAFT_CAPTURE " + result.saveToFile(captureDir + "/config-draft-conflict.png"))
                        captureFinished = true
                    })
                    for (let n = 0; n < 100 && !captureFinished; n++) wait(20)
                }
                keyClick(Qt.Key_Return)
                compare(Config.profile.displayName, "Cambio externo", "Enter cannot overwrite external edit")
                verify(!page.commitDrafts(), "Save cannot commit stale draft")

                editor.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                typeText("Mi decision")
                compare(page.conflicts["profile.displayName"], undefined, "new edit resolves conflict")
                keyClick(Qt.Key_Return)
                compare(Config.profile.displayName, "Mi decision")
                verify(Config.dirty)
                verify(Config.save())
                for (let n = 0; n < 200 && (Config.saving || Config.dirty); n++) wait(20)
                verify(!Config.saving && !Config.dirty && !Config.error, "save finished")

                editor.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                typeText("Descartar")
                verify(page.hasDrafts)
                verify(Config.update({profile: {displayName: "Cambio secundario"}}).ok)
                verify(page.conflicts["profile.displayName"], "discard starts from a conflict")
                Config.discard()
                page.clearValidation()
                compare(Config.profile.displayName, "Mi decision")
                verify(!page.hasDrafts && !page.validationError, "discard clears draft")
                console.log("PASS: external draft conflict, explicit edit, save and discard")
                finished = true
            }
        }
    }
}
