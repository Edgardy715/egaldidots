import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
import "windows"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: navigation; focusedMonitorName: Quickshell.screens[0].name }
    IslandOverlay { id: overlay; router: navigation; modelData: Quickshell.screens[0] }
    TestCase {
        id: checks
        parent: overlay.contentItem
        name: "SettingsSurfaceSwitch"
        when: Config.loaded && overlay.visible
        property bool finished: false
        function findMethod(item, method) {
            if (typeof item[method] === "function") return item
            for (const child of item.children || []) {
                const found = findMethod(child, method)
                if (found) return found
            }
            return null
        }
        function open(surface) {
            console.log("SWITCH", surface)
            navigation.toggleSurface("", surface)
            tryCompare(navigation, "openSurface", surface, 5000)
        }
        function findFont(item) {
            if (item.objectName === "fontPicker" && item.visible && item.enabled) return item
            for (const child of item.children || []) {
                const found = findFont(child)
                if (found) return found
            }
            return null
        }
        function capture(name) {
            const directory = Quickshell.env("ISLA_SWITCH_CAPTURE_DIR")
            if (!directory) return
            let done = false
            let scene = findMethod(overlay.contentItem, "showProfile")
            while (scene.parent && scene.parent !== overlay.contentItem) scene = scene.parent
            scene.grabToImage(image => {
                verify(image.saveToFile(directory + "/" + name + ".png"))
                done = true
            })
            tryVerify(() => done, 3000)
        }
        function test_switching() {
            try {
            for (const mode of [{layout: "split", reduced: false}, {layout: "compact", reduced: false},
                                {layout: "split", reduced: true}, {layout: "compact", reduced: true}]) {
                const reduced = mode.reduced
                console.log("MODE", mode.layout, reduced)
                verify(Config.update({appearance: {reduceMotion: reduced, barLayout: mode.layout}}).ok)
                navigation.reduceMotion = reduced
                tryCompare(overlay, "compact", mode.layout === "compact", 5000)
                open("settings")
                let editor = null
                tryVerify(() => {
                    editor = findMethod(overlay.contentItem, "showProfile")
                    return editor && editor.contentReady
                }, 5000)
                editor.showProfile()
                const page = findMethod(editor, "choosePath")
                verify(page !== null)
                page.setDraft("profile", "displayName", "Borrador conservado")
                page.choosePath("paths", "userAvatar")
                tryVerify(() => overlay.settingsPickerOpen)
                if (mode.layout === "split" && !reduced) capture("settings-picker")
                console.log("PICKER_READY")
                open("launcher")
                if (mode.layout === "split" && !reduced) capture("settings-to-launcher")
                tryVerify(() => !editor.contentReady && !page.pickerOpen)
                let input = null
                tryVerify(() => {
                    input = findChild(overlay.contentItem, "launcherSearch")
                    return input !== null && input.visible && input.enabled
                }, 5000)
                input.forceActiveFocus()
                console.log("DESTINATION_FOCUS", input.activeFocus)
                verify(input.activeFocus)
                overlay.profileRequest++
                console.log("AFTER_HIDDEN_PROFILE", input.activeFocus)
                verify(input.activeFocus, "hidden profile navigation must not steal launcher focus")
                wait(600)
                verify(input.activeFocus, "settling callback must not remove destination input focus")
                keyClick(Qt.Key_A, Qt.ControlModifier)
                for (const letter of "texto destino") keyClick(letter)
                compare(input.text, "texto destino")
                keyClick(Qt.Key_S, Qt.ControlModifier)
                compare(page.drafts["profile.displayName"], "Borrador conservado")
                verify(Config.profile.displayName !== "Borrador conservado", "hidden Ctrl+S cannot commit draft")
                if (mode.layout === "split" && !reduced) capture("launcher-focused")
                compare(page.drafts["profile.displayName"], "Borrador conservado")
                for (const surface of ["calendar", "mixer", "connectivity", "notifs", "appearance", "wallpaper", "overview", "media", "session", "utils", "workspaces", "clipboard"]) {
                    open(surface)
                    compare(editor.contentReady, false)
                    verify(!page.pickerOpen)
                    open("settings")
                    tryVerify(() => editor.contentReady, 5000)
                    compare(findMethod(overlay.contentItem, "showProfile"), editor)
                    compare(page.drafts["profile.displayName"], "Borrador conservado")
                }
                open("launcher")
                navigation.toggleSurface("", "calendar")
                navigation.toggleSurface("", "settings")
                tryCompare(navigation, "openSurface", "settings", 5000)
                tryVerify(() => editor.contentReady, 5000)
                compare(page.drafts["profile.displayName"], "Borrador conservado")
                editor.page = 3
                let fontPicker = null
                tryVerify(() => {
                    fontPicker = findFont(page)
                    return fontPicker !== null
                }, 5000)
                console.log("FONT_PICKER_READY")
                fontPicker.popup.open()
                tryVerify(() => fontPicker.popup.visible)
                open("mixer")
                tryVerify(() => !fontPicker.popup.visible)
                open("settings")
                tryVerify(() => editor.contentReady, 5000)
                compare(page.drafts["profile.displayName"], "Borrador conservado")
                navigation.close()
                tryCompare(navigation, "openSurface", "")
                tryVerify(() => !editor.contentReady)
            }
            console.log("PASS: settings picker, hidden focus/shortcuts, destination typing, retained drafts, rapid retarget and 13 destinations in split/compact with normal/reduced motion")
            finished = true
            } catch (error) {
                console.error("FAIL: settings switch", error.message)
                finished = true
            }
        }
    }
    Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    Timer { interval: 90000; running: true; onTriggered: Qt.exit(2) }
}
