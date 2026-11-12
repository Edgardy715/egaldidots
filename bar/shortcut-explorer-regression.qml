import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

// Shortcut explorer with an injected binds backend: never touches Hyprland.
ShellRoot {
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 250; onTriggered: Qt.exit(exitCode) }
    QtObject {
        id: fake
        property var binds: [
            {id: "app.terminal", label: "Terminal", group: "Aplicaciones", key: "SUPER + Q", enabled: true, cmd: "kitty", dispatcher: "exec_cmd", flags: [], conflicts: []},
            {id: "app.files", label: "Archivos", group: "Aplicaciones", key: "SUPER + Q", enabled: true, cmd: "nautilus", dispatcher: "exec_cmd", flags: [], conflicts: ["Terminal"]},
            {id: "app.browser", label: "Navegador", group: "Aplicaciones", key: "SUPER + CTRL + B", enabled: true, overridden: true, cmd: "zen-browser", dispatcher: "exec_cmd", flags: [], conflicts: []},
            {id: "win.close", label: "Cerrar ventana", group: "Ventanas", key: "SUPER + C", enabled: true, dispatcher: "killactive", flags: [], conflicts: []},
            {id: "win.off", label: "Desactivado", group: "Ventanas", key: "SUPER + D", enabled: false, dispatcher: "x", flags: [], conflicts: []},
            {id: "window.drag", label: "Mover ventana", group: "Ventanas", key: "SUPER + mouse:272", enabled: true, dispatcher: "", flags: ["mouse"], conflicts: []},
            {id: "custom.1", label: "Notas", group: "Personalizados", key: "SUPER + ALT + N", enabled: true, custom: true, cmd: "kitty -e nvim", dispatcher: "exec_cmd", flags: [], conflicts: []}]
        property var external: [
            {id: "external.0", label: "Atajo de la configuración", group: "Submapa scrolloverview", key: "left", enabled: true, external: true, submap: "scrolloverview", dispatcher: "lua", flags: [], conflicts: []},
            {id: "external.1", label: "Captura", group: "Configuración", key: "Print", enabled: true, external: true, cmd: "grim", dispatcher: "exec_cmd", flags: [], conflicts: []}]
        property string layout: "us"
        property string keymapName: "English (US)"
        property int loadCalls: 0
        property int layoutCalls: 0
        function load() { loadCalls++ }
        function refreshLayout() { layoutCalls++ }
    }
    Window {
        id: window
        visible: true; width: 848; height: 528
        color: Theme.background
        ShortcutExplorer {
            id: explorer
            anchors.fill: parent; anchors.margins: 16
            binds: fake
            property int closeRequests: 0
            property string edited: ""
            onRequestClose: closeRequests++
            onEditRequested: id => edited = id
        }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property bool finished: false
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function capture(name) {
                window.contentItem.grabToImage(result => result.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/" + name + ".png"))
                wait(300)
            }
            function key(sym) { return findChild(explorer, "shortcutKey-" + sym) }
            function labelsOnBoard() {
                const out = []
                for (const row of explorer.board) for (const k of row.main.concat(row.nav)) if (!k.gap) out.push(k.label)
                return out
            }
            function reopen() { explorer.open = false; wait(30); explorer.open = true; wait(60) }
            function test_explorer() {
                if (finished) return
                finished = true
                try {
                    Config.update({appearance: {reduceMotion: true}})
                    explorer.open = true; wait(120)
                    const search = findChild(explorer, "shortcutsSearch")
                    assert(fake.loadCalls === 1 && fake.layoutCalls === 1, "open loads binds and layout")
                    assert(search.activeFocus, "search focused on open")
                    assert(findChild(explorer, "shortcutsLayout").text.includes("ANSI"), "us layout labelled ANSI")
                    assert(labelsOnBoard().indexOf("Q") >= 0 && !key("ntilde"), "ANSI board has letters, no Ñ")

                    // Bound keys and conflicts under the default Super set.
                    assert(explorer.keyIndex.q.length === 2 && explorer.keyIndex.c.length === 1, "super index")
                    assert(!explorer.keyIndex.d, "disabled bind not lit")
                    assert(!explorer.keyIndex.n, "Super+Alt bind not under plain Super")
                    assert(explorer.modSets[0].id === "SUPER", "most used set first: " + JSON.stringify(explorer.modSets))
                    mouseClick(key("q")); wait(60)
                    assert(explorer.selectedKey === "q" && search.activeFocus, "click selects key: " + explorer.selectedKey + " focus " + search.activeFocus + " " + key("q").width + "x" + key("q").height + " vis " + key("q").visible)
                    assert(findChild(explorer, "shortcutsInspectorTitle").text === "Terminal", "inspector shows bind")
                    capture("shortcuts-us")
                    mouseClick(findChild(explorer, "shortcutsEdit")); wait(30)
                    assert(explorer.edited === "app.terminal", "edit hands off id: " + explorer.edited)
                    mouseClick(key("x")); wait(30)
                    assert(findChild(explorer, "shortcutsInspector").b === null, "free key shows no bind")

                    // Hover previews without selecting.
                    mouseMove(key("c"), 10, 10); wait(60)
                    assert(explorer.hoveredKey === "c" && findChild(explorer, "shortcutsInspectorTitle").text === "Cerrar ventana", "hover inspects")
                    mouseMove(explorer, 2, 2); wait(30)

                    // Modifier chips and clicking modifier keys.
                    explorer.chosenMods = ["SUPER", "CTRL"]; wait(30)
                    assert(explorer.keyIndex.b && !explorer.keyIndex.q, "Super+Ctrl set")
                    mouseClick(key("@CTRL")); wait(30)
                    assert(explorer.mods.join("+") === "SUPER", "clicking Ctrl key toggles it off")

                    // Holding modifiers previews that set, release restores chips.
                    keyPress(Qt.Key_Meta, Qt.MetaModifier); keyPress(Qt.Key_Alt, Qt.MetaModifier | Qt.AltModifier); wait(30)
                    assert(explorer.mods.join("+") === "SUPER+ALT" && explorer.keyIndex.n, "held mods: " + explorer.mods)
                    capture("shortcuts-held")
                    keyRelease(Qt.Key_Alt, Qt.MetaModifier); keyRelease(Qt.Key_Meta, Qt.NoModifier); wait(30)
                    assert(explorer.heldMods.length === 0 && explorer.mods.join("+") === "SUPER", "release restores")

                    // Search: command, keys, external; arrows + Enter pick a result.
                    keyClick(Qt.Key_K); keyClick(Qt.Key_I); keyClick(Qt.Key_T); wait(60)
                    assert(explorer.query === "kit" && explorer.results.length === 2, "search by command: " + explorer.results.length)
                    assert(findChild(explorer, "shortcutsResults").visible, "results replace the board")
                    capture("shortcuts-search")
                    keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); wait(60)
                    assert(explorer.query === "" && explorer.selectedKey === "n" && explorer.mods.join("+") === "SUPER+ALT", "pick Notas")
                    explorer.query = "grim"; wait(30)
                    assert(explorer.results.length === 1 && explorer.results[0].external, "external searchable")
                    explorer.query = "ctrl b"; wait(30)
                    assert(explorer.results.length === 1 && explorer.results[0].id === "app.browser", "search by keys")
                    explorer.query = "scrolloverview"; wait(30)
                    keyClick(Qt.Key_Return); wait(30)
                    assert(explorer.edited === "external.0", "submap result opens manager")
                    explorer.query = "zzz"; wait(30)
                    assert(explorer.results.length === 0, "no match")

                    // Escape: first clears, second asks to close.
                    search.forceActiveFocus()
                    keyClick(Qt.Key_Escape); wait(20)
                    assert(explorer.query === "" && explorer.closeRequests === 0, "escape clears query")
                    keyClick(Qt.Key_Escape); wait(20)
                    assert(explorer.closeRequests === 1, "escape closes")

                    // External binds are read-only in the explorer too.
                    mouseClick(key("print")); wait(30)
                    assert(!findChild(explorer, "shortcutsEdit").visible, "no edit for external")

                    // Reopen leaves no stale state.
                    explorer.query = "kit"; explorer.chosenMods = ["CTRL"]; explorer.selectedKey = "q"
                    reopen()
                    assert(explorer.query === "" && search.text === "" && explorer.mods.join("+") === "SUPER" && !explorer.selectedKey, "reopen resets")
                    assert(fake.loadCalls === 2, "reopen reloads")

                    // ISO Spanish and unknown layouts.
                    fake.layout = "es"; fake.keymapName = "Spanish"; wait(60)
                    assert(key("ntilde") && key("less") && findChild(explorer, "shortcutsLayout").text.includes("ISO"), "es ISO board")
                    capture("shortcuts-es")
                    fake.layout = ""; fake.keymapName = "German"; wait(60)
                    const labels = labelsOnBoard()
                    assert(labels.indexOf("Q") < 0 && labels.indexOf("1") < 0 && labels.indexOf("Esc") >= 0, "unknown layout: letters blank")
                    assert(findChild(explorer, "shortcutsLayout").text.includes("German"), "unknown layout named")
                    assert(explorer.unlabeled === 5, "unknown layout: letter binds counted apart, got " + explorer.unlabeled)
                    capture("shortcuts-unknown")
                    fake.layout = "us"; fake.keymapName = "English (US)"

                    // Interrupted cross-fade with motion on: ends where the last target says.
                    Config.update({appearance: {reduceMotion: false}}); wait(30)
                    const results = findChild(explorer, "shortcutsResults")
                    explorer.query = "k"; wait(60); explorer.query = ""; wait(40); explorer.query = "t"; wait(40); explorer.query = ""
                    tryCompare(results, "opacity", 0, 1000)
                    tryCompare(results, "visible", false, 1000)
                    explorer.query = "t"; tryCompare(results, "opacity", 1, 1000)
                    explorer.query = ""; wait(400)

                    // Closing drops held modifiers.
                    keyPress(Qt.Key_Shift, Qt.ShiftModifier); wait(20)
                    explorer.closing = true; wait(20)
                    assert(explorer.heldMods.length === 0, "closing clears held mods")
                    keyRelease(Qt.Key_Shift, Qt.NoModifier)
                    explorer.closing = false

                    // Rebuild cost of the board (index + delegates) on a mods change.
                    let t0 = Date.now()
                    for (let i = 0; i < 40; i++) explorer.chosenMods = i % 2 ? ["SUPER"] : ["SUPER", "SHIFT"]
                    console.log("PERF: 40 modifier switches " + (Date.now() - t0) + " ms")
                    t0 = Date.now()
                    for (let i = 0; i < 40; i++) fake.layout = i % 2 ? "us" : "es"
                    console.log("PERF: 40 layout rebuilds " + (Date.now() - t0) + " ms")
                    console.log("PASS: shortcut explorer")
                } catch (e) {
                    console.log("FAIL: " + e.message)
                    exitCode = 1
                }
                finish.start()
            }
        }
    }
}
