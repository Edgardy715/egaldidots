import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"
ShellRoot {
    Window {
        id: window
        visible: true; width: 800; height: 620
        SettingsPage { id: page; anchors.fill: parent; config: Config; section: "appearance"; fieldKeys: ["appearance.topGap"] }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ConfigBoundEditor"
            when: window.visible
            property bool finished: false
            function findType(item, typeName) {
                if (String(item).startsWith(typeName + "_")) return item
                for (const child of item.children || []) { const found = findType(child, typeName); if (found) return found }
                return null
            }
            function test_large_number() {
                tryCompare(Config, "loaded", true)
                const editor = findType(page, "EdotsTextField")
                verify(editor !== null, "number editor found")
                editor.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                for (const letter of "1e308") keyClick(letter)
                console.log("AUDIT_TYPED " + JSON.stringify({text: editor.text, draft: page.hasDrafts}))
                keyClick(Qt.Key_Return)
                console.log("AUDIT_NUMBER " + JSON.stringify({value: Config.appearance.topGap, dirty: Config.dirty, error: page.validationError}))
                finished = true
            }
        }
    }
}
