import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 250; onTriggered: Qt.exit(exitCode) }
    QtObject {
        id: backend
        property bool available: true
        property bool busy: false
        property bool dirty: false
        property string error: ""
        property string feedback: ""
        property string persistenceError: ""
        property string version: "0.56.2"
        property bool animationsEnabled: true
        property bool workspacesChildrenOverridden: false
        property var editableLeaves: ({windowsIn: true, windowsOut: true, workspaces: true})
        property var springLeaves: ({})
        property var baseline: ({layout: "scrolling", windowsIn: {enabled: true, speed: 2.6, style: "popin 94%"}, windowsOut: {enabled: true, speed: 1.8, style: "popin 97%"}, workspaces: {enabled: true, speed: 3.2, style: "slide"}})
        property var values: JSON.parse(JSON.stringify(baseline))
        property int saved: 0
        property bool initialized: false
        function initialize() { initialized = true }
        function refresh() { if (!dirty) error = "" }
        function update(patch) {
            const next = JSON.parse(JSON.stringify(values))
            for (const key of Object.keys(patch)) next[key] = typeof patch[key] === "object" ? Object.assign({}, next[key], patch[key]) : patch[key]
            values = next; dirty = JSON.stringify(values) !== JSON.stringify(baseline)
            return {ok: true}
        }
        function save() { saved++; baseline = JSON.parse(JSON.stringify(values)); dirty = false; feedback = "Cambios guardados" }
        function discard() { values = JSON.parse(JSON.stringify(baseline)); dirty = false }
        function resetSaved() { persistenceError = ""; error = ""; feedback = "Archivo recuperado" }
    }
    Window {
        id: window
        visible: true; width: 1000; height: 700
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        EdotsWindow { id: editor; anchors.fill: parent; hyprlandController: backend }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property bool finished: false
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function capture(name) {
                window.contentItem.grabToImage(result => result.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/" + name + ".png"))
                wait(300)
            }
            function test_hyprland() {
                if (finished) return
                finished = true
                try {
                    for (const scale of [1, 1.75]) {
                        Config.update({appearance: {fontScale: scale, reduceMotion: true}})
                        for (const size of [{w:1000,h:700}, {w:640,h:560}]) {
                            window.width = size.w; window.height = size.h
                            editor.page = 6; wait(350)
                            const page = findChild(editor, "hyprlandPage")
                            const save = findChild(editor, "hyprlandSave")
                            const scroll = findChild(editor, "hyprlandScroll")
                            const tab = findChild(editor, "settingsNav6")
                            assert(page.visible && backend.initialized, "page initialized")
                            assert(tab.width >= 44 && tab.height >= 44 && tab.mapToItem(editor, 0, tab.height).y <= editor.height, "new navigation fits")
                            assert(scroll.height > 80, "usable scroll viewport: " + scroll.height)
                            assert(save.mapToItem(editor, 0, save.height).y <= editor.height, "save footer fits")
                            assert(!save.enabled, "save disabled without changes")
                            capture("hyprland-" + size.w + "-font-" + scale)
                        }
                    }
                    Config.update({appearance: {fontScale: 1}})
                    window.width = 1000; window.height = 700; wait(200)
                    const layout = findChild(editor, "hyprlandLayout")
                    const mosaic = findChild(layout, "choice-dwindle")
                    mouseClick(mosaic); wait(50)
                    assert(backend.values.layout === "dwindle" && backend.dirty, "layout click previews actual choice")
                    assert(findChild(editor,"hyprlandStatus").text.includes("Vista previa"), "preview status")
                    Config.discard()
                    editor.page = 0; wait(50)
                    assert(findChild(editor,"settingsStatus").text.includes("Hyprland"), "pending compositor preview visible on other pages")
                    editor.page = 6; wait(50)
                    assert(!findChild(editor,"hyprlandRefresh").enabled, "refresh cannot lose preview")
                    mouseClick(findChild(editor, "hyprlandDiscard")); wait(50)
                    assert(backend.values.layout === "scrolling" && !backend.dirty, "revert")
                    const style = findChild(editor, "hyprland-windowsIn-style")
                    const styleChoice = findChild(style, "choice-slide")
                    const scroll = findChild(editor, "hyprlandScroll")
                    scroll.contentItem.contentY += styleChoice.mapToItem(scroll, 0, 0).y - scroll.height / 2
                    wait(100)
                    mouseClick(styleChoice); wait(50)
                    assert(backend.values.windowsIn.style === "slide", "style click previews")
                    editor.saveChanges(); wait(50)
                    assert(backend.saved === 1 && !backend.dirty, "Ctrl+S path saves Hyprland only")
                    assert(!Config.dirty || Config.appearance.fontScale === 1, "shell config unrelated")
                    backend.editableLeaves = {windowsIn:false, windowsOut:true, workspaces:true}; wait(50)
                    assert(!findChild(editor,"hyprland-windowsIn-style").editable, "inherited animation remains unchanged")
                    backend.springLeaves = {windowsOut:true}; wait(50)
                    assert(!findChild(editor,"hyprland-windowsOut-duration").editable, "spring duration not misleading")
                    backend.persistenceError = "Archivo inválido"; backend.error = backend.persistenceError; wait(50)
                    assert(!layout.editable && findChild(editor,"hyprlandRecover").visible, "invalid file recovery explicit")
                    mouseClick(findChild(editor,"hyprlandRecover")); wait(50)
                    assert(!backend.persistenceError && layout.editable, "recover returns control")
                    backend.available = false; backend.error = "Sin sesión Hyprland"; wait(50)
                    assert(!layout.editable && !findChild(editor,"hyprlandSave").enabled, "unavailable controls disabled")
                    capture("hyprland-unavailable")
                    editor.searchQuery = "workspace"; wait(100)
                    assert(findChild(editor,"hyprlandSearchResult").visible, "global search locates compositor page")
                    mouseClick(findChild(editor,"hyprlandSearchResult")); wait(100)
                    assert(editor.page === 6 && !editor.searchQuery, "search opens page")
                    Config.discard()
                    console.log("PASS: Hyprland settings UI, preview, revert, save, inheritance, offline and responsive layout")
                    finish.start()
                } catch (error) { console.error("FAIL: Hyprland settings UI", error); exitCode = 1; finish.start() }
            }
        }
    }
}
