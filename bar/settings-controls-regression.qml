import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true; width: 880; height: 720
        visibility: Window.FullScreen
        color: Theme.background
        Item {
            id: bounds
            x: 20; y: 20; width: 840; height: 680
            ModuleComposer { id: composer; x: 0; y: 0; width: 800; config: Config }
            SettingRow {
                id: switchRow; x: 0; y: 205; width: 600
                reducedMotion: Config.appearance.reduceMotion
                fieldKey: "time12h"; field: Config.schema.sections.appearance.time12h
                value: Config.appearance.time12h
                onChangeRequested: next => Config.update({appearance: {time12h: next}})
            }
            SettingRow {
                id: sliderRow; x: 0; y: 285; width: 600
                reducedMotion: Config.appearance.reduceMotion
                fieldKey: "fontScale"; field: Config.schema.sections.appearance.fontScale
                value: Config.appearance.fontScale
                onChangeRequested: next => Config.update({appearance: {fontScale: next}})
            }
            SettingRow {
                id: fontRow; x: 0; y: 435; width: 650
                popupBounds: bounds
                reducedMotion: Config.appearance.reduceMotion
                fieldKey: "fontFamily"; field: Config.schema.sections.appearance.fontFamily
                value: Config.appearance.fontFamily
                onChangeRequested: next => { Config.update({appearance: {fontFamily: next}}); draftText = undefined }
                onDraftChanged: text => draftText = text
                onAccepted: draftText = undefined
            }
            EdotsTextField { id: input; x: 0; y: 620; width: 400; placeholderText: "Nombre" }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "EdotsControls"
            when: window.visible
            property bool finished: false
            function verify(ok, message) {
                if (!ok) { console.error("FAIL: Edots controls: " + message); throw new Error(message) }
            }
            function compare(actual, expected, message) { verify(actual === expected, (message || "value") + ": " + actual + " != " + expected) }
            function tryCompare(object, key, expected) {
                for (let i = 0; i < 100 && object[key] !== expected; i++) wait(20)
                compare(object[key], expected, key)
            }
            function typeText(text) { for (let i = 0; i < text.length; i++) keyClick(text.charAt(i)) }
            function findType(item, typeName) {
                if (String(item).startsWith(typeName + "_")) return item
                for (const child of item.children || []) { const found = findType(child, typeName); if (found) return found }
                return null
            }
            function test_native_controls() {
                tryCompare(Config, "loaded", true)
                wait(180)
                const parentButton = findChild(composer, "module-systemStatus")
                const appsButton = findChild(composer, "module-apps")
                mouseClick(parentButton, parentButton.width / 2, parentButton.height / 2)
                compare(Config.modules.systemStatus, false)
                verify(appsButton.enabled)
                mouseClick(appsButton, appsButton.width / 2, appsButton.height / 2)
                compare(Config.modules.apps, true)
                compare(Config.modules.systemStatus, true)
                compare(parentButton.checked, true)
                mouseClick(appsButton, appsButton.width / 2, appsButton.height / 2)
                compare(Config.modules.apps, false)
                mouseClick(appsButton, appsButton.width / 2, appsButton.height / 2)
                compare(Config.modules.apps, true)
                const combo = findChild(fontRow, "fontPicker")
                verify(combo)
                const original = Config.appearance.fontFamily
                mouseClick(combo, combo.width - 18, combo.height / 2)
                tryCompare(combo.popup, "visible", true)
                compare(Config.appearance.fontFamily, original)
                verify(combo.popup.height <= 280)
                const bottom = bounds.mapToItem(combo.popup.parent, 0, bounds.height).y
                verify(combo.popup.y + combo.popup.height <= bottom - 11)
                const list = combo.popup.contentItem
                const selectedIndex = combo.model.indexOf("Inter")
                verify(selectedIndex >= 0)
                list.positionViewAtIndex(selectedIndex, ListView.Center)
                wait(150)
                const option = list.itemAtIndex(selectedIndex)
                verify(option, "native option instantiated")
                mouseClick(option, option.width / 2, option.height / 2)
                tryCompare(combo.popup, "visible", false)
                tryCompare(Config.appearance, "fontFamily", "Inter")
                compare(combo.editText, "Inter")
                compare(fontRow.draftText, undefined)
                combo.forceActiveFocus()
                keyClick(Qt.Key_Down, Qt.AltModifier)
                tryCompare(combo.popup, "visible", true)
                keyClick(Qt.Key_Down)
                keyClick(Qt.Key_Return)
                tryCompare(combo.popup, "visible", false)
                verify(Config.appearance.fontFamily !== "Inter", "keyboard selection committed")
                const beforeEscape = Config.appearance.fontFamily
                keyClick(Qt.Key_Down, Qt.AltModifier)
                tryCompare(combo.popup, "visible", true)
                keyClick(Qt.Key_Down)
                keyClick(Qt.Key_Escape)
                tryCompare(combo.popup, "visible", false)
                compare(Config.appearance.fontFamily, beforeEscape, "Escape cancels highlighted option")
                combo.contentItem.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                typeText("Edots Custom Font")
                keyClick(Qt.Key_Return)
                wait(120)
                compare(Config.appearance.fontFamily, "Edots Custom Font")
                compare(combo.editText, "Edots Custom Font")
                keyClick(Qt.Key_A, Qt.ControlModifier)
                typeText("Edots Tab Font")
                keyClick(Qt.Key_Tab)
                wait(120)
                compare(Config.appearance.fontFamily, "Edots Tab Font", "Tab commits custom text")
                input.forceActiveFocus()
                typeText("isla")
                compare(input.text, "isla")
                keyClick(Qt.Key_A, Qt.ControlModifier)
                compare(input.selectedText, "isla")
                keyClick(Qt.Key_Backspace)
                compare(input.text, "")
                const toggle = findType(switchRow, "Switch")
                verify(toggle)
                const beforeToggle = Config.appearance.time12h
                mouseClick(toggle, toggle.width / 2, toggle.height / 2)
                compare(Config.appearance.time12h, !beforeToggle)
                toggle.forceActiveFocus()
                keyClick(Qt.Key_Space)
                compare(Config.appearance.time12h, beforeToggle)
                const slider = findType(sliderRow, "Slider")
                verify(slider)
                mouseClick(slider, slider.width * 0.75, slider.height / 2)
                verify(Config.appearance.fontScale > 1)
                Config.update({appearance: {reduceMotion: true}})
                combo.popup.open()
                wait(100)
                compare(combo.popup.scale, 1)
                fontRow.visible = false
                tryCompare(combo.popup, "visible", false)
                Config.discard()
                console.log("PASS: native combo pointer/keyboard/custom font, bounded popup, text editing, switch/slider and module restoration")
                finished = true
            }
        }
    }
}
