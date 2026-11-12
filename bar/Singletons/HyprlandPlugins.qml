pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Plugin state for the Hyprland settings page. One helper process at a time;
// scripts/hypr-plugins.py owns detection, build, backup and the atomic swap.
Singleton {
    id: root

    property var plugins: []
    property string hyprlandVersion: ""
    property int staleCount: 0
    property bool checked: false
    property string error: ""
    property string feedback: ""
    property string updatingId: ""
    readonly property bool busy: _operation !== ""

    property string _operation: ""

    function status() { launch("status", []) }
    function check() { launch("check", []) }
    function update(id) {
        if (!id || busy) return false
        updatingId = id
        feedback = ""
        launch("update", [id])
        return true
    }

    function launch(operation, args) {
        if (busy) return
        if (operation !== "status") error = ""
        _operation = operation
        bridge.command = ["python3", Quickshell.shellDir + "/scripts/hypr-plugins.py", operation].concat(args)
        bridge.running = true
    }

    function finish(code) {
        const operation = _operation
        let result = null
        try { result = JSON.parse(output.text) } catch (e) { result = null }
        _operation = ""
        if (!result) {
            error = I18n.tr("No se pudo consultar los plugins de Hyprland.")
            updatingId = ""
            return
        }
        if (operation === "update") {
            const id = updatingId
            updatingId = ""
            if (!result.ok) { error = result.error || I18n.tr("La actualización falló."); return }
            feedback = I18n.tr("%1 actualizado a %2. Se aplicará al reiniciar Hyprland.").arg(id).arg(result.version)
            launch("check", [])
            return
        }
        if (!result.ok) { error = result.error || I18n.tr("No se pudo consultar los plugins de Hyprland."); return }
        plugins = result.plugins || []
        hyprlandVersion = result.hyprland ? result.hyprland.version : ""
        staleCount = result.staleCount || 0
        if (operation === "check") checked = true
    }

    Process {
        id: bridge
        stdout: StdioCollector { id: output }
        onExited: (code) => Qt.callLater(() => root.finish(code))
    }
}
