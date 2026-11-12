pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for keybinds, shared by the Crucible manager and the
// island shortcut explorer. scripts/hypr-binds.py owns validation, conflicts,
// the atomic write of binds.user.json, backups, live apply and rollback.
Singleton {
    id: root

    property var binds: []
    property var external: []
    property int conflictCount: 0
    property bool canUndo: false
    property bool loaded: false
    // False when Hyprland has no binds.lua: live binds are shown read-only.
    property bool catalogReady: true
    property string error: ""
    property string feedback: ""
    readonly property bool busy: _running
    property bool _running: false
    // Id a caller wants selected once the manager opens (explorer → manager).
    property string focusId: ""

    // Keyboard layout of Hyprland's main keyboard: "us", "es" or "" (unknown).
    property string layout: ""
    property string keymapName: ""

    // Capture: while recording a shortcut, the compositor sits in the empty
    // isla_capture submap so existing binds don't fire. Escape always leaves it
    // (non_consuming bind in binds.lua); the watchdog and destruction also do.
    property bool capturing: false

    function load() { launch(["list"]) }
    function setKey(id, keys) { return launch(["set", id, keys]) }
    function disable(id) { return launch(["disable", id]) }
    function enable(id) { return launch(["enable", id]) }
    function reset(id) { return launch(["reset", id]) }
    function resetAll() { return launch(["reset-all"]) }
    function add(label, keys, cmd) { return launch(["add", label, keys, cmd]) }
    function edit(id, label, keys, cmd) { return launch(["edit", id, label, keys, cmd]) }
    function remove(id) { return launch(["remove", id]) }
    function undo() { return launch(["undo"]) }

    function beginCapture() {
        if (capturing) { watchdog.restart(); return }
        capturing = true
        watchdog.restart()
        setSubmap("isla_capture")
    }
    function endCapture() {
        watchdog.stop()
        if (!capturing) return
        capturing = false
        setSubmap("reset")
    }
    // One hyprctl at a time, latest wish wins: enter/leave can't arrive out of order.
    property string _submapWant: ""
    function setSubmap(name) { _submapWant = name; if (!submapProc.running) runSubmap() }
    function runSubmap() {
        submapProc.command = ["hyprctl", "dispatch", "hl.dsp.submap(\"" + _submapWant + "\")"]
        _submapWant = ""
        submapProc.running = true
    }
    Process { id: submapProc; onExited: if (root._submapWant) root.runSubmap() }

    function refreshLayout() { if (!keymapProc.running) keymapProc.running = true }

    function launch(args) {
        if (_running) return false
        _running = true
        if (args[0] !== "list") feedback = ""
        bridge.command = ["python3", Quickshell.shellDir + "/scripts/hypr-binds.py"].concat(args)
        bridge.running = true
        return true
    }

    function finish() {
        let result = null
        try { result = JSON.parse(output.text) } catch (e) { result = null }
        _running = false
        if (!result) { error = I18n.tr("No se pudo leer los atajos de Hyprland."); return }
        if (!result.ok) { error = result.error || I18n.tr("No se pudo aplicar el atajo."); return }
        error = ""
        if (result.catalog !== undefined) catalogReady = result.catalog !== false
        binds = result.binds || []
        external = result.external || []
        conflictCount = result.conflictCount || 0
        canUndo = !!result.canUndo
        loaded = true
    }

    Process {
        id: bridge
        stdout: StdioCollector { id: output }
        onExited: Qt.callLater(() => root.finish())
    }

    Process {
        id: keymapProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kb = null
                try {
                    const all = JSON.parse(text).keyboards || []
                    kb = all.find(k => k.main) || all[0] || null
                } catch (e) { kb = null }
                const name = kb ? String(kb.active_keymap || "") : ""
                root.keymapName = name
                // Only claim a layout when the name is unambiguous.
                root.layout = name === "English (US)" ? "us" : name === "Spanish" ? "es" : ""
            }
        }
    }

    // binds.lua rewrites the catalog on every reload/rebind; follow it so edits
    // made elsewhere (hyprctl reload, another Crucible) show up without reopening.
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/isla-binds-catalog.json"
        watchChanges: true
        printErrors: false
        onFileChanged: if (root.loaded) followUp.restart()
    }
    Timer { id: followUp; interval: 250; onTriggered: if (!root._running) root.load(); else restart() }

    Timer { id: watchdog; interval: 20000; onTriggered: root.endCapture() }

    Component.onDestruction: if (capturing) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])
}
