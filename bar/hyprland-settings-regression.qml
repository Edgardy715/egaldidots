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
    QtObject {
        id: pluginsBackend
        property var plugins: [
            {id: "hyprglass", name: "Hyprglass", version: "1.1.1", state: "loaded", latest: "1.1.1", updateAvailable: false, stale: false, message: ""},
            {id: "scrolloverview", name: "Scroll overview", version: "abc", state: "incompatible", latest: "def", updateAvailable: true, stale: true, message: ""}]
        property string hyprlandVersion: "0.57.1"
        property int staleCount: 1
        property string error: ""
        property string feedback: ""
        property string updatingId: ""
        property bool busy: false
        property int statusCalls: 0
        property int checkCalls: 0
        property string updated: ""
        function status() { statusCalls++ }
        function check() { checkCalls++ }
        function update(id) { updated = id; return true }
    }
    QtObject {
        id: bindsBackend
        property var binds: [
            {id: "app.terminal", label: "Terminal", group: "Aplicaciones", default: "SUPER + Q", key: "SUPER + Q", enabled: true, overridden: false, cmd: "kitty", dispatcher: "exec_cmd", flags: [], conflicts: []},
            {id: "app.browser", label: "Navegador", group: "Aplicaciones", default: "SUPER + B", key: "SUPER + CTRL + B", enabled: true, overridden: true, cmd: "zen-browser", dispatcher: "exec_cmd", flags: [], conflicts: ["Terminal"]},
            {id: "window.drag", label: "Mover ventana", group: "Ventanas", default: "SUPER + mouse:272", key: "SUPER + mouse:272", enabled: true, overridden: false, dispatcher: "", flags: ["mouse"], conflicts: []},
            {id: "custom.1", label: "Notas", group: "Personalizados", default: "SUPER + ALT + N", key: "SUPER + ALT + N", enabled: true, custom: true, cmd: "kitty -e nvim", dispatcher: "exec_cmd", flags: [], conflicts: []}]
        property var external: [
            {id: "external.0", label: "Atajo de la configuración", group: "Submapa scrolloverview", default: "", key: "left", enabled: true, external: true, submap: "scrolloverview", dispatcher: "lua", flags: [], conflicts: []}]
        property int conflictCount: 1
        property bool canUndo: true
        property bool loaded: true
        property string error: ""
        property string feedback: ""
        property bool busy: false
        property bool capturing: false
        property string focusId: ""
        property int loadCalls: 0
        property int captureCalls: 0
        property int releaseCalls: 0
        property var set: ({})
        property string disabledId: ""
        property string enabledId: ""
        property string resetId: ""
        property string removedId: ""
        property var added: null
        property var edited: null
        property int undoCalls: 0
        property int resetAllCalls: 0
        function load() { loadCalls++ }
        function setKey(id, keys) { set = {id: id, keys: keys}; return true }
        function disable(id) { disabledId = id }
        function enable(id) { enabledId = id }
        function reset(id) { resetId = id }
        function resetAll() { resetAllCalls++ }
        function add(label, keys, cmd) { added = {label: label, keys: keys, cmd: cmd} }
        function edit(id, label, keys, cmd) { edited = {id: id, label: label, keys: keys, cmd: cmd} }
        function remove(id) { removedId = id }
        function undo() { undoCalls++ }
        function beginCapture() { captureCalls++; capturing = true }
        function endCapture() { if (capturing) releaseCalls++; capturing = false }
    }
    Window {
        id: window
        visible: true; width: 1000; height: 700
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        EdotsWindow { id: editor; anchors.fill: parent; hyprlandController: backend; pluginsController: pluginsBackend; bindsController: bindsBackend }
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
                            editor.systemTab = "hyprland"; editor.page = 7; wait(350)
                            const page = findChild(editor, "hyprlandPage")
                            const save = findChild(editor, "hyprlandSave")
                            const scroll = findChild(editor, "hyprlandScroll")
                            const tab = findChild(editor, "settingsNav5")
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
                    editor.systemTab = "hyprland"; editor.page = 7; wait(50)
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
                    editor.systemTab = "hyprland"; editor.page = 7; wait(100)
                    assert(pluginsBackend.statusCalls > 0, "plugins state requested on open")
                    assert(findChild(editor,"hyprlandPlugins").visible, "plugins section visible")
                    assert(findChild(editor,"hyprlandPluginsStale").visible, "stale plugins warned")
                    const checkButton = findChild(editor,"hyprlandPluginsCheck")
                    scroll.contentItem.contentY += checkButton.mapToItem(scroll, 0, 0).y - scroll.height / 3; wait(100)
                    mouseClick(checkButton); wait(50)
                    assert(pluginsBackend.checkCalls === 1, "check button runs check")
                    assert(!findChild(editor,"hyprlandPluginUpdate-hyprglass").visible, "up-to-date plugin has no update")
                    const updateButton = findChild(editor,"hyprlandPluginUpdate-scrolloverview")
                    scroll.contentItem.contentY += updateButton.mapToItem(scroll, 0, 0).y - scroll.height / 2; wait(100)
                    mouseClick(updateButton); wait(50)
                    assert(pluginsBackend.updated === "scrolloverview", "update button updates that plugin")
                    pluginsBackend.busy = true; wait(50)
                    assert(!findChild(editor,"hyprlandPluginsCheck").enabled, "check disabled while busy")
                    pluginsBackend.busy = false
                    capture("hyprland-plugins")
                    editor.showShortcuts(); wait(150)
                    const kb = findChild(editor, "keybindsPage")
                    const title = () => findChild(editor, "keybindDetailTitle").text
                    const row = id => findChild(editor, "keybindRow-" + id)
                    assert(kb.visible && bindsBackend.loadCalls > 0, "shortcuts tab loads binds")
                    assert(title() === "Terminal", "first bind inspected: " + title())
                    mouseClick(row("app.browser")); wait(50)
                    assert(title() === "Navegador" && findChild(editor,"keybindConflicts").visible, "conflict shown in inspector")
                    assert(findChild(editor,"keybindAction").text === "zen-browser", "command shown")
                    mouseClick(findChild(editor,"hyprlandBindReset")); wait(50)
                    assert(bindsBackend.resetId === "app.browser", "restore default")
                    mouseClick(row("app.terminal")); wait(50)
                    assert(!findChild(editor,"hyprlandBindReset").visible, "default bind has no restore")
                    mouseClick(findChild(editor,"hyprlandBindToggle")); wait(50)
                    assert(bindsBackend.disabledId === "app.terminal", "switch disables that bind")
                    const record = findChild(editor,"hyprlandBindChange")
                    mouseClick(record); wait(50)
                    assert(bindsBackend.capturing && findChild(editor,"keybindKeySink").activeFocus, "recording inhibits compositor binds and owns focus")
                    keyClick(Qt.Key_Escape); wait(50)
                    assert(!bindsBackend.capturing && kb.recState === "" && !bindsBackend.set.id, "Esc cancels and releases capture")
                    mouseClick(record); wait(50)
                    keyPress(Qt.Key_Shift, Qt.ShiftModifier); wait(30)
                    assert(kb.recState === "listen" && kb.liveMods.join() === "SHIFT", "modifier alone keeps listening: " + kb.liveMods)
                    keyRelease(Qt.Key_Shift, Qt.ShiftModifier); wait(30)
                    assert(kb.liveMods.length === 0, "released modifier leaves the preview")
                    keyClick(Qt.Key_T, Qt.MetaModifier | Qt.ShiftModifier); wait(50)
                    assert(kb.recState === "review" && kb.candidate === "SUPER + SHIFT + T" && !bindsBackend.capturing, "combination captured: " + kb.candidate)
                    capture("keybinds-review")
                    mouseClick(findChild(editor,"keybindConfirm")); wait(50)
                    assert(bindsBackend.set.id === "app.terminal" && bindsBackend.set.keys === "SUPER + SHIFT + T", "captured combination is sent: " + JSON.stringify(bindsBackend.set))
                    mouseClick(record); wait(50)
                    keyClick(Qt.Key_B, Qt.MetaModifier | Qt.ControlModifier); wait(50)
                    assert(kb.candidateClashes.join() === "Navegador" && !findChild(editor,"keybindConfirm").enabled, "clash blocks saving")
                    mouseClick(findChild(editor,"keybindRetry")); wait(50)
                    keyClick(Qt.Key_T); wait(50)
                    assert(kb.candidateBare && !findChild(editor,"keybindConfirm").enabled, "bare letter refused")
                    assert(findChild(editor,"keybindRetry").activeFocus, "disabled save: focus parks on retry")
                    keyClick(Qt.Key_Escape); wait(50)
                    assert(kb.recState === "" && editor.visible, "Esc in review cancels without closing")
                    mouseClick(record); wait(50)
                    keyClick(Qt.Key_Q, Qt.NoModifier, -1); kb.candidate = "code:49"; wait(20)
                    assert(kb.candidateBare, "bare scan code refused")
                    mouseClick(findChild(editor,"keybindCancel")); wait(50)
                    mouseClick(record); wait(50)
                    bindsBackend.endCapture(); wait(50)
                    assert(kb.recState === "", "capture ended elsewhere stops listening")
                    mouseClick(record); wait(50)
                    mouseClick(findChild(editor,"keybindsSearch")); wait(50)
                    assert(kb.recState === "" && !bindsBackend.capturing, "losing focus cancels recording")
                    mouseClick(row("window.drag")); wait(50)
                    assert(!record.enabled, "mouse binds are not remappable")
                    kb.filter = "external"; wait(50)
                    mouseClick(row("external.0")); wait(50)
                    assert(findChild(editor,"keybindReadOnly").visible && !findChild(editor,"hyprlandBindToggle").visible && !record.enabled, "external binds are read-only")
                    kb.filter = "all"; kb.query = "naveg"; wait(50)
                    assert(kb.rows.length === 1 && kb.rows[0].id === "app.browser", "search by label")
                    kb.query = "nvim"; wait(50)
                    assert(kb.rows.length === 1 && kb.rows[0].id === "custom.1", "search by command")
                    kb.query = "ctrl b"; wait(50)
                    assert(kb.rows.length === 1 && kb.rows[0].id === "app.browser", "search by keys")
                    kb.query = ""; wait(50)
                    mouseClick(row("custom.1")); wait(50)
                    const cmdField = findChild(editor,"keybindCommandField")
                    assert(cmdField.visible && findChild(editor,"keybindRemove").visible, "custom bind editable")
                    mouseClick(cmdField); keyClick(Qt.Key_End); keyClick(Qt.Key_Space); keyClick(Qt.Key_X); wait(50)
                    mouseClick(findChild(editor,"keybindSaveCustom")); wait(50)
                    assert(bindsBackend.edited && bindsBackend.edited.cmd === "kitty -e nvim x" && bindsBackend.edited.keys === "SUPER + ALT + N", "custom edit sent: " + JSON.stringify(bindsBackend.edited))
                    mouseClick(findChild(editor,"keybindRemove")); wait(50)
                    assert(bindsBackend.removedId === "custom.1", "custom remove")
                    mouseClick(findChild(editor,"keybindsNew")); wait(50)
                    assert(kb.drafting && findChild(editor,"keybindLabelField").activeFocus, "new bind drafts with focus on name")
                    keyClick(Qt.Key_P); wait(20)
                    mouseClick(findChild(editor,"keybindCommandField")); keyClick(Qt.Key_L); keyClick(Qt.Key_S); wait(20)
                    assert(!findChild(editor,"keybindCreate").enabled, "create needs a combination")
                    mouseClick(record); wait(50)
                    keyClick(Qt.Key_P, Qt.MetaModifier | Qt.AltModifier); wait(50)
                    mouseClick(findChild(editor,"keybindConfirm")); wait(50)
                    assert(findChild(editor,"hyprlandBindCapturePrompt").visible === false, "chosen draft combination shown as keycaps")
                    capture("keybinds-draft")
                    mouseClick(findChild(editor,"keybindCreate")); wait(50)
                    assert(bindsBackend.added && bindsBackend.added.label === "p" && bindsBackend.added.cmd === "ls" && bindsBackend.added.keys === "SUPER + ALT + P", "create sent: " + JSON.stringify(bindsBackend.added))
                    mouseClick(findChild(editor,"keybindDiscardDraft")); wait(50)
                    mouseClick(findChild(editor,"keybindsUndo")); wait(50)
                    assert(bindsBackend.undoCalls === 1, "undo")
                    mouseClick(findChild(editor,"hyprlandBindsResetAll")); wait(50)
                    assert(bindsBackend.resetAllCalls === 1, "reset all")
                    editor.page = 0; wait(100)
                    bindsBackend.focusId = "app.browser"; wait(150)
                    assert(editor.page === 6 && kb.selectedId === "app.browser" && !bindsBackend.focusId, "explorer hand-off opens the bind")
                    editor.page = 0; wait(100)
                    assert(!bindsBackend.capturing, "capture never left on")
                    editor.showShortcuts(); wait(150)
                    capture("hyprland-keybinds")
                    window.width = 640; window.height = 560; wait(200)
                    const kbDetail = findChild(editor,"keybindDetail")
                    assert(kbDetail.mapToItem(window.contentItem, 0, 0).x + kbDetail.width <= 640 + 1, "keybind detail fits a narrow window")
                    capture("keybinds-640")
                    window.width = 1000; window.height = 700; wait(200)
                    editor.showSystem("hyprland"); wait(100)
                    backend.available = false; backend.error = "Sin sesión Hyprland"; wait(50)
                    assert(!layout.editable && !findChild(editor,"hyprlandSave").enabled, "unavailable controls disabled")
                    capture("hyprland-unavailable")
                    editor.searchQuery = "workspace"; wait(100)
                    assert(findChild(editor,"hyprlandSearchResult").visible, "global search locates compositor page")
                    mouseClick(findChild(editor,"hyprlandSearchResult")); wait(100)
                    assert(editor.page === 7 && editor.systemTab === "hyprland" && !editor.searchQuery, "search opens page")
                    Config.discard()
                    console.log("PASS: Hyprland settings UI, preview, revert, save, inheritance, offline and responsive layout")
                    finish.start()
                } catch (error) { console.error("FAIL: Hyprland settings UI", error); exitCode = 1; finish.start() }
            }
        }
    }
}
