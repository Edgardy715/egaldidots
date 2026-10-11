import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true; width: 1100; height: 800
        color: Theme.background
        Item {
            id: stage
            width: 1000; height: 700
            Rectangle { anchors.fill: parent; color: Theme.background }
            EdotsWindow { id: editor; anchors.fill: parent }
        }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property bool finished: false
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function findPage(item) {
                if (typeof item.setDraft === "function") return item
                for (const child of item.children || []) { const p = findPage(child); if (p) return p }
                return null
            }
            function capture(name) {
                const dir = Quickshell.env("ISLA_SETTINGS_UX_CAPTURE_DIR")
                if (!dir) return
                let done = false
                stage.grabToImage(image => { done = image.saveToFile(dir + "/" + name + ".png") })
                tryVerify(() => done, 3000)
            }
            function contrast(fg, bg) {
                function luminance(c) {
                    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
                    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
                }
                const a = luminance(fg), b = luminance(bg)
                return (Math.max(a,b) + 0.05) / (Math.min(a,b) + 0.05)
            }
            function test_settingsUX() {
                try {
                    wait(600)
                    const page = findPage(editor)
                    const search = findChild(editor, "settingsSearch")
                    const save = findChild(editor, "settingsSave")
                    assert(page && search && save, "controls available")
                    Config.discard()
                    editor.feedback = "Cambios guardados"
                    Config.update({appearance:{time12h: !Config.appearance.time12h}})
                    assert(findChild(editor,"settingsStatus").text.includes("Vista previa"), "unsaved state supersedes old feedback")
                    Config.discard(); editor.feedback = ""
                    assert(!save.enabled, "save disabled without changes")
                    for (const scale of [1, 1.75]) {
                        Config.update({appearance:{fontScale:scale, reduceMotion:true}})
                        for (const size of [{w:1000,h:700}, {w:640,h:560}]) {
                            stage.width = size.w; stage.height = size.h
                            for (let index = 0; index < 6; index++) {
                                editor.page = index
                                wait(160)
                                const tab = findChild(editor, "settingsNav" + index)
                                assert(tab && tab.width >= 44 && tab.height >= 44, "navigation target")
                                const label = save.contentItem.children.find(child => child.text === "Guardar")
                                assert(label && label.mapToItem(save,label.width,0).x <= save.width - 8, "save label fits button")
                                const bottom = save.mapToItem(editor, 0, save.height).y
                                assert(bottom <= editor.height && save.mapToItem(editor,0,0).x >= 0, "save remains visible")
                                assert((index === 1 && editor.richComposition) || (page.height > 70 && page.width > 240), "settings stay scrollable: " + index + " " + size.w + " font " + scale + " height " + page.height)
                                if (size.w === 1000 && scale === 1) capture("page-" + index)
                            }
                            capture("size-" + size.w + "-font-" + scale)
                        }
                    }
                    stage.width = 1000; stage.height = 700
                    Config.update({appearance:{fontScale:1,reduceMotion:true}})
                    editor.page = 4; wait(100)
                    page.setDraft("paths","userAvatar","relative/path")
                    editor.page = 2; wait(100)
                    editor.saveChanges()
                    wait(200)
                    assert(editor.validationError.length > 0, "invalid draft preserved")
                    assert(editor.searchQuery.length > 0, "hidden error made visible")
                    assert(window.activeFocusItem && window.activeFocusItem.Accessible.name.length > 0, "invalid editor focused and labelled")
                    capture("validation")
                    stage.width = 640; stage.height = 560
                    Config.update({appearance:{fontScale:1.75}})
                    wait(200); page.focusFirstError(); wait(100)
                    const input = window.activeFocusItem
                    const inputTop = input.mapToItem(editor,0,0).y
                    const inputBottom = input.mapToItem(editor,0,input.height).y
                    capture("validation-compact")
                    assert(inputTop >= page.mapToItem(editor,0,0).y && inputBottom <= page.mapToItem(editor,0,page.height).y, "focused invalid field within scroll viewport: " + inputTop + ".." + inputBottom + " page " + page.mapToItem(editor,0,0).y + ".." + page.mapToItem(editor,0,page.height).y)
                    assert(save.mapToItem(editor,0,save.height).y <= editor.height, "error footer visible at large text")
                    const inlineError = findChild(page, "settingValidation")
                    assert(inlineError && inlineError.mapToItem(editor,0,inlineError.height).y <= page.mapToItem(editor,0,page.height).y, "inline error visible with focused field")
                    capture("validation-compact")
                    stage.width = 1000; stage.height = 700
                    Config.update({appearance:{fontScale:1}})
                    page.clearValidation(); Config.discard()
                    editor.searchQuery = "no-result-fixture-xyz"
                    wait(100)
                    assert(editor.resultCount === 0, "empty search")
                    capture("empty-search")
                    editor.searchQuery = ""
                    Config.update({appearance:{fontScale:1.75,reduceMotion:true}})
                    page.choosePath("paths","userAvatar")
                    const picker = findChild(page,"edotsPathPicker")
                    picker.width = 600; picker.height = 500
                    const temporary = Quickshell.env("ISLA_CONFIG")
                    picker.navigate(page.fileUrl(temporary.slice(0,temporary.lastIndexOf("/"))))
                    wait(200)
                    const confirm = findChild(picker,"confirmPath")
                    const location = findChild(picker,"pickerLocation")
                    assert(confirm && location && confirm.mapToItem(picker.contentItem,confirm.width,confirm.height).x <= picker.contentItem.width, "compact picker action fits")
                    assert(location.width > 200, "compact picker location usable")
                    const dir = Quickshell.env("ISLA_SETTINGS_UX_CAPTURE_DIR")
                    if (dir) {
                        let done = false
                        picker.contentItem.grabToImage(image => { done = image.saveToFile(dir + "/picker-compact.png") })
                        tryVerify(() => done,3000)
                    }
                    picker.close()
                    Config.discard()
                    editor.page = 0
                    for (const palette of [{name:"dark", bg:"#101213", fg:"#c2c2c6", accent:"#ac5b4f"},
                                           {name:"light", bg:"#f4f6f8", fg:"#1b1f24", accent:"#2563eb"}]) {
                        IslaPalette.background = palette.bg; IslaPalette.foreground = palette.fg; IslaPalette.accent = palette.accent
                        wait(1400)
                        const fg = Theme.foreground, bg = Theme.background
                        const secondary = Qt.rgba(fg.r*0.72+bg.r*0.28, fg.g*0.72+bg.g*0.28, fg.b*0.72+bg.b*0.28,1)
                        assert(contrast(fg,bg)>=4.5 && contrast(secondary,bg)>=4.5, "primary and secondary contrast " + palette.name)
                        assert(contrast(Theme.error,bg)>=4.5, "error contrast " + palette.name)
                        capture("theme-" + palette.name)
                    }
                    console.log("PASS: settings UX navigation, responsive layouts, font scaling, save state, hidden validation focus, empty search and dark/light contrast")
                } catch (error) { console.error("FAIL: settings UX", error.message) }
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 60000; running: true; onTriggered: Qt.exit(2) }
}
