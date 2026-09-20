pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Isla · KeepAwake. Wrapper del "keep awake" / "caffeine" (mantiene la pantalla
 * despierta). El type nativo `Quickshell.Wayland.IdleInhibitor` NO se usa en
 * esta config porque el master-compiled binario lo marca como static_plugin
 * sin inicialización automática (el linker descarta qt_static_plugin_*). Véase
 * comentario en este archivo al momento de la migración.
 *
 * Por qué NO nombrarlo `IdleInhibitor.qml`: en quickshell master, importar
 * `Quickshell.Wayland` registra el type público `IdleInhibitor` globalmente.
 * Cuando un archivo del mismo directorio (Singletons/) declara
 * `pragma Singleton ... IdleInhibitor {...}`, QML da precedencia al type
 * importado sobre el singleton local → el wrapper nunca se instancia y el
 * IpcHandler nunca se registra. Renombrar a `KeepAwake` evita la colisión.
 *
 * Implementación: `systemd-inhibit --what=idle --who=Isla --why="Keep Awake"
 * sleep 100000000` lanzado/matado via Process. Es el método estándar de
 * systemd (D-Bus a org.freedesktop.login1). Funciona con cualquier compositor
 * que respete inhibidores (Hyprland, Sway, GNOME, KDE).
 *
 * Uso desde keybinds:
 *   bind = $mainMod+Shift+comma, exec, qs -c bar ipc call island.keepAwake.toggle 0
 */
Singleton {
    id: root

    Component.onCompleted: console.log("[KeepAwake] wrapper instanciado (systemd-inhibit)")

    // Estado persistente: el toggle sobrevive al hot-reload de quickshell.
    // `enabled` delega en props.enabled; si el reload ocurre con el inhibitor
    // activo, onEnabledChanged re-arranca el Process. `enabledSince` NO se
    // persiste (date no serializa bien) → el contador reinicia en reload.
    property alias enabled: props.enabled
    property date enabledSince: new Date(0)
    property date now: new Date()
    readonly property string elapsedTime: {
        if (!enabled || enabledSince.getTime() === 0) return "--:--"
        var secs = Math.floor((root.now.getTime() - enabledSince.getTime()) / 1000)
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        return (h > 0 ? (h + ":") : "")
            + (m < 10 && h > 0 ? "0" : "") + m + ":"
            + (s < 10 ? "0" : "") + s
    }

    PersistentProperties {
        id: props
        reloadableId: "keepAwake"
        property bool enabled: false
    }

    // solo corre mientras está activo (cero trabajo en reposo)
    Timer {
        interval: 1000
        repeat: true
        running: root.enabled
        onTriggered: root.now = new Date()
    }

    signal toggled(bool enabled)

    onEnabledChanged: {
        if (enabled) enabledSince = new Date()
        else enabledSince = new Date(0)
        inhibitProc.running = enabled
        root.toggled(enabled)
    }

    function toggle(): void { root.enabled = !root.enabled }
    function enable(): void { root.enabled = true }
    function disable(): void { root.enabled = false }

    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle",
                  "--who=Isla", "--why=Keep Awake",
                  "sleep", "100000000"]
        running: false
    }

    IpcHandler {
        target: "island.keepAwake"
        function isEnabled(): bool { return root.enabled }
        function enable(): void { root.enable() }
        function disable(): void { root.disable() }
        function toggle(): void { root.toggle() }
    }
}
