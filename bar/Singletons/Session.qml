pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Isla · Session. Envuelve los comandos logout/shutdown/reboot/lock/hibernate con
 * `Quickshell.execDetached` + IPC `island.session.*`. Inspira en
 * caelestia/services/SessionManager.qml.
 *
 * Comandos son default seguros (hyprland/systemd). Edite en Flags si quiere
 * `sddm`/`greetd`/`systemd`/`niri msg` etc.
 *
 * Uso desde keybinds:
 *   bind = $mainMod+L, exec, qs -c bar ipc call island.session.lock ""
 *   bind = SUPER+M, exec, qs -c bar ipc call island session "" # abre surface
 */
Singleton {
    id: root

    Component.onCompleted: console.log("[Session] singleton instanciado")

    // Comandos (override via Flags en el futuro — por ahora valores seguros)
    readonly property string lockCmd: "~/.local/bin/isla-lock"
    readonly property string logoutCmd: "hyprctl dispatch exit 0"
    readonly property string shutdownCmd: "systemctl poweroff"
    readonly property string rebootCmd: "systemctl reboot"
    readonly property string hibernateCmd: "systemctl hibernate"
    readonly property string suspendCmd: "systemctl suspend"

    function _run(cmd: string): void {
        if (!cmd || cmd.length === 0) return
        try { Quickshell.execDetached(["sh", "-c", cmd]) } catch (e) {}
    }

    function lock(): void { _run(lockCmd) }
    function logout(): void { _run(logoutCmd) }
    function shutdown(): void { _run(shutdownCmd) }
    function reboot(): void { _run(rebootCmd) }
    function hibernate(): void { _run(hibernateCmd) }
    function suspend(): void { _run(suspendCmd) }

    IpcHandler {
        target: "island.session"
        function lock(): void { root.lock() }
        function logout(): void { root.logout() }
        function shutdown(): void { root.shutdown() }
        function reboot(): void { root.reboot() }
        function hibernate(): void { root.hibernate() }
        function suspend(): void { root.suspend() }
    }
}
