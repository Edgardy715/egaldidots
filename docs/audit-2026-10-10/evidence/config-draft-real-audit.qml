import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"
ShellRoot {
    Window {
        id: window
        visible: true; width: 800; height: 620
        SettingsPage { id: page; anchors.fill: parent; config: Config; section: "profile"; fieldKeys: ["profile.displayName"] }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            property bool finished: false
            name: "ConfigDraftExternal"
            when: window.visible
            function findType(item, typeName) {
                if (String(item).startsWith(typeName + "_")) return item
                for (const child of item.children || []) { const found = findType(child, typeName); if (found) return found }
                return null
            }
            function test_external_edit() {
                tryCompare(Config, "loaded", true)
                const editor = findType(page, "EdotsTextField")
                verify(editor !== null, "profile editor found")
                editor.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                for (const letter of "Mi borrador") keyClick(letter)
                compare(editor.text, "Mi borrador")
                verify(page.hasDrafts, "keyboard edit created draft")
                console.log("AUDIT_DRAFT_READY")
                for (let n = 0; n < 200 && Config.profile.displayName !== "Cambio externo"; n++) wait(20)
                compare(Config.profile.displayName, "Cambio externo", "external FileView reload")
                keyClick(Qt.Key_Return)
                for (let n = 0; n < 30 && Config.profile.displayName !== "Mi borrador"; n++) wait(20)
                console.log("AUDIT_RESULT " + JSON.stringify({effective: Config.profile.displayName, dirty: Config.dirty, drafts: page.hasDrafts}))
                compare(Config.profile.displayName, "Mi borrador", "Enter commits stale draft")
                verify(Config.dirty, "stale draft became pending save")
                finished = true
            }
        }
    }
}
