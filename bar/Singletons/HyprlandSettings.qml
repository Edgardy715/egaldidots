pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Runtime preview is serialized through one helper process. The helper owns
// validation, Hyprland argv and the separate atomic Isla settings file.
Singleton {
    id: root

    property bool available: false
    readonly property bool busy: _running || preview.running
    property bool dirty: false
    property string error: ""
    property string persistenceError: ""
    property string feedback: ""
    property string version: ""
    property var values: ({})
    property var editableLeaves: ({ windowsIn: false, windowsOut: false, workspaces: false })
    property bool animationsEnabled: true
    property bool workspacesChildrenOverridden: false
    property var springLeaves: ({ windowsIn: false, windowsOut: false, workspaces: false })

    property bool _initialized: false
    property bool _saveRequested: false
    property var _saved: ({})
    property var _baseline: ({})
    property var _actual: ({})
    property var _digest: null
    property string _operation: ""
    property bool _running: false

    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

    function matchesRuntime(target, actual) {
        if (target.layout !== actual.layout) return false
        for (const leaf of ["windowsIn", "windowsOut", "workspaces"]) {
            if (target[leaf].enabled !== actual[leaf].enabled) return false
            if (target[leaf].enabled && !same(target[leaf], actual[leaf])) return false
        }
        return true
    }

    function curveFor(raw, leaf) {
        let source = raw[leaf]
        if (!source.overridden) source = raw[leaf === "workspaces" ? "global" : "windows"]
        if (!source.overridden) source = raw.global
        return source.bezier
    }

    function isSpring(raw, leaf) {
        return typeof curveFor(raw, leaf) === "string" && curveFor(raw, leaf).startsWith("spring:")
    }

    function savedCurve(leaf) {
        const live = _actual.raw[leaf]
        const curve = live.enabled ? curveFor(_actual.raw, leaf) : ""
        return typeof curve === "string" && /^(?:spring:)?[A-Za-z_][A-Za-z_0-9-]*$/.test(curve)
            ? curve : curveFor(_baseline.raw, leaf)
    }

    function initialize() {
        if (_initialized || busy) return
        launch("initialize")
    }

    function refresh() {
        if (busy || dirty) return false
        launch("refresh")
        return true
    }

    function update(patch) {
        if (!available || persistenceError || _operation === "save" && busy || !patch || typeof patch !== "object" || Array.isArray(patch))
            return { ok: false, error: "Hyprland settings unavailable" }
        const next = JSON.parse(JSON.stringify(values))
        for (const key of Object.keys(patch)) {
            if (key === "layout") next.layout = patch.layout
            else if (key === "windowsIn" || key === "windowsOut" || key === "workspaces") {
                if (!editableLeaves[key] || !patch[key] || typeof patch[key] !== "object" || Array.isArray(patch[key]))
                    return { ok: false, error: "Animation is inherited or invalid: " + key }
                for (const field of Object.keys(patch[key])) {
                    if (field !== "enabled" && field !== "speed" && field !== "style")
                        return { ok: false, error: "Unknown animation field: " + field }
                    next[key][field] = patch[key][field]
                }
            } else return { ok: false, error: "Unknown Hyprland field: " + key }
        }
        values = next
        dirty = !same(values, _saved)
        error = persistenceError
        feedback = ""
        if (!busy) preview.restart()
        return { ok: true }
    }

    function discard() {
        if (!available || _operation === "save" && busy) return false
        _saveRequested = false
        values = JSON.parse(JSON.stringify(_saved))
        dirty = false
        error = persistenceError
        feedback = ""
        if (!busy) preview.restart()
        return true
    }

    function save() {
        if (!available || error.length || persistenceError) return false
        if (!dirty) return true
        _saveRequested = true
        if (!busy) preview.restart()
        return true
    }

    function resetSaved() {
        if (!available || !persistenceError || busy || dirty) return false
        launch("reset")
        return true
    }

    function launch(operation) {
        if (_running) return
        _running = true
        _operation = operation
        let command = ["python3", Quickshell.shellDir + "/scripts/hyprland-settings.py", operation]
        if (operation === "apply") command.push(JSON.stringify(values), JSON.stringify(_baseline))
        else if (operation === "save" || operation === "reset") command.push(
            JSON.stringify(operation === "reset" ? _actual.values : values), JSON.stringify(_digest),
            JSON.stringify({ windowsIn: savedCurve("windowsIn"), windowsOut: savedCurve("windowsOut"),
                workspaces: savedCurve("workspaces") }))
        bridge.command = command
        bridge.running = true
    }

    function accept(result) {
        if (_operation === "initialize" || _operation === "refresh") {
            _initialized = true
            available = true
            _actual = result.runtime
            _baseline = result.baseline
            _saved = result.saved
            _digest = result.digest
            persistenceError = result.persistenceError || ""
            error = persistenceError
            const shown = JSON.parse(JSON.stringify(result.runtime.values))
            if (result.digest) {
                for (const leaf of ["windowsIn", "windowsOut", "workspaces"]) {
                    if (!shown[leaf].enabled && !result.saved[leaf].enabled)
                        shown[leaf] = result.saved[leaf]
                }
            }
            values = _operation === "initialize" && result.digest ? result.saved : shown
            dirty = !same(values, _saved)
            version = result.runtime.version || ""
            animationsEnabled = result.runtime.animationsEnabled
            const raw = result.runtime.raw
            workspacesChildrenOverridden = raw.workspacesIn?.overridden === true || raw.workspacesOut?.overridden === true
            editableLeaves = {
                windowsIn: raw.windowsIn.overridden === true,
                windowsOut: raw.windowsOut.overridden === true,
                workspaces: raw.workspaces.overridden === true
            }
            springLeaves = { windowsIn: isSpring(raw, "windowsIn"), windowsOut: isSpring(raw, "windowsOut"),
                workspaces: isSpring(raw, "workspaces") }
        } else if (_operation === "apply") {
            if (result.runtime.retainedCurves) {
                const baseline = JSON.parse(JSON.stringify(_baseline))
                for (const leaf of Object.keys(result.runtime.retainedCurves))
                    baseline.raw[leaf].bezier = result.runtime.retainedCurves[leaf]
                _baseline = baseline
            }
            _actual = result.runtime
            animationsEnabled = result.runtime.animationsEnabled
            workspacesChildrenOverridden = result.runtime.raw.workspacesIn?.overridden === true || result.runtime.raw.workspacesOut?.overridden === true
            springLeaves = { windowsIn: isSpring(result.runtime.raw, "windowsIn"),
                windowsOut: isSpring(result.runtime.raw, "windowsOut"),
                workspaces: isSpring(result.runtime.raw, "workspaces") }
        } else if (_operation === "save") {
            _digest = result.digest
            _saved = JSON.parse(JSON.stringify(values))
            dirty = false
            _saveRequested = false
            feedback = "Guardado para próximos inicios de Isla"
        } else if (_operation === "reset") {
            _digest = result.digest
            _saved = JSON.parse(JSON.stringify(_actual.values))
            values = _saved
            dirty = false
            persistenceError = ""
            feedback = "Sesión actual guardada; copia del archivo anterior: " + result.backup
        }
    }

    function finish(code) {
        let result
        try { result = JSON.parse(output.text) }
        catch (exception) { result = { ok: false, error: "Invalid Hyprland helper response" } }
        if (code !== 0 || !result.ok) {
            error = result.error || "Hyprland settings failed"
            if (_operation === "apply") {
                if (result.runtime) {
                    _actual = result.runtime
                    animationsEnabled = result.runtime.animationsEnabled
                } else if (error.indexOf("rollback failed") !== -1) {
                    available = false
                }
                values = _actual.values
                dirty = available && !same(values, _saved)
            }
            _saveRequested = false
        } else {
            error = ""
            accept(result)
        }
        _operation = ""
        _running = false
        if (available && !error.length) {
            if (!matchesRuntime(values, _actual.values)) preview.restart()
            else if (_saveRequested) root.launch("save")
        }
    }

    Timer { id: preview; interval: 70; onTriggered: root.launch("apply") }

    Process {
        id: bridge
        stdout: StdioCollector { id: output }
        onExited: (code) => Qt.callLater(() => root.finish(code))
    }
}
