//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma IconTheme "hicolor"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Singletons"
import "components"
import "windows"

/**
 * Isla · shell. Puerto de Ricelin `pill/shell.qml`: dos `PanelWindow` por
 * monitor (Variants sobre Quickshell.screens):
 *
 *  - `reserve`: tira vacía que sólo reserva struts (exclusionMode Normal,
 *    exclusiveZone = alto de la pill en reposo, aboveWindows, mask = Region
 *    vacío = click-through). Las ventanas tileadas nunca montan sobre la pill.
 *  - `overlay`: full-screen transparente, WlrLayer.Overlay, exclusionMode
 *    Ignore, namespace "quickshell.island"; ancla la única Pill top-centre y
 *    enruta el input con máscara tri-estado:
 *        monFullscreen ? hiddenRegion : (modal ? fullRegion : pillRegion)
 *    reposo → sólo la pill captura clicks (el resto va a ventanas); surface
 *    abierta → capa entera + backdrop-dismiss; fullscreen → click-through + pill
 *    retraída.
 *
 * `IpcHandler { target: "island" }` expone clock/mixer/media/calendar/peek/hide
 * para keybinds. Un monitor vacío resuelve al foco. Raw-event allowlist →
 * `refresh()` (sólo lo que cambia lo renderizado).
 */
ShellRoot {
    id: root

    settings.watchFiles: true

    SurfaceRouter {
        id: navigation
        focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        reduceMotion: Flags.reduceMotion
        resultsDuration: Motion.standard
        morphDuration: Motion.morph
        onAuthCloseRequested: {
            if (Auth.sudoActive) Auth.cancelSudo()
            if (Auth.active) Auth.cancel()
        }
        onOpenSurfaceChanged: {
            WinMap.active = navigation.openSurface === "overview"
            if (WinMap.active) WinMap.updateAll()
            Notifs.centerOpen = navigation.openSurface === "notifs"
        }
    }

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        // fuerza instanciación de singletons referenciándolos explícitamente
        refresh()
        Config.loaded
        Brightness.available
        Session.lockCmd
        Auth.active
        KeepAwake.enabled      // fuerza singleton KeepAwake
    }

    Binding {
        target: Auth; property: "polkitFeedbackDuration"
        value: Flags.reduceMotion ? 220 : Math.max(750, Motion.morph + Motion.iconSwap + Motion.fast)
    }
    Binding {
        target: Auth; property: "sudoFeedbackDuration"
        value: Flags.reduceMotion ? 220 : Math.max(1100, Motion.morph + Motion.iconSwap + Motion.fast)
    }

    // Polkit entrega las solicitudes gráficas directamente a la pill. Las
    // solicitudes de sudo del wrapper Fish usan el puente askpass; sudo valida.
    Connections {
        target: Auth
        function openAuthSurface() {
            var mon = Hyprland.focusedMonitor
            if (!mon && Quickshell.screens.length > 0)
                mon = Quickshell.screens[0]
            navigation.present(mon ? mon.name : "", "auth")
            console.log("[Auth] surface monitor:", navigation.openMon)
        }
        function onAuthenticationRequestStarted() {
            openAuthSurface()
        }
        function onSudoRequestStarted() {
            console.log("[Auth] opening sudo surface")
            openAuthSurface()
        }
        function onPresentingChanged() {
            if (Auth.presenting) {
                if (navigation.openSurface !== "auth") openAuthSurface()
            } else if (navigation.openSurface === "auth") navigation.close()
        }

    }

    /** Sólo estos raw-events cambian lo que la pill renderiza. */
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name]) root.refresh();
        }
    }

    IpcHandler {
        target: "island"
        function clock(mon: string): bool     { navigation.toggleSurface(mon, "calendar"); return true; }
        function calendar(mon: string): bool   { navigation.toggleSurface(mon, "calendar"); return true; }
        function mixer(mon: string): bool      { navigation.toggleSurface(mon, "mixer"); return true; }
        function media(mon: string): bool { navigation.toggleSurface(mon, "media"); return true; }
        function workspaces(mon: string): bool { navigation.toggleSurface(mon, "workspaces"); return true; }
        function notifs(mon: string): bool   { navigation.toggleSurface(mon, "notifs"); return true; }
        function wallpaper(mon: string): bool { navigation.toggleSurface(mon, "wallpaper"); return true; }
        function launcher(mon: string): bool { navigation.toggleSurface(mon, "launcher"); return true; }
        /** Clipboard history (cliphist). Super+V por defecto. */
        function clipboard(mon: string): bool { navigation.toggleSurface(mon, "clipboard"); return true; }
        /** Utilities (KeepAwake + Brillo + QuickToggles). Super+U por defecto. */
        function utils(mon: string): bool { navigation.toggleSurface(mon, "utils"); return true; }
        /** Connectivity panel: Wi-Fi + Bluetooth completo. */
        function connectivity(mon: string): bool { navigation.toggleSurface(mon, "connectivity"); return true; }
        /** Session menu: logout/shutdown/reboot/lock. Super+M abre el panel. */
        function session(mon: string): bool { navigation.toggleSurface(mon, "session"); return true; }
        function peek(mon: string): bool       { navigation.peek(mon); return true; }
        function hide(): bool                  { navigation.close(); return true; }
        /** Abre cualquier surface por nombre — puerta para scripting. */
        function page(mon: string, name: string): bool { navigation.toggleSurface(mon, name); return true; }
        /** Overview (alt+tab estilo windows): surface de la pill con mini-ventanas
         *  vivas + navegación por teclado. Toggle con `qs -c bar ipc call island
         *  overview ""` (Super+Tab). Mientras está abierto el overlay toma foco de
         *  teclado Exclusive → Tab/flechas ciclan ventanas, Enter focusa, Esc sale. */
        function overview(mon: string): bool { navigation.toggleSurface(mon, "overview"); return true; }
        /** Recarga los colores de pywal tras un cambio de wallpaper.
         *  Lo invoca el script de setWallpaper via:
         *  qs -c bar ipc call island reloadColors "" */
        function reloadColors(): bool { IslaPalette.forceReload(); return true; }
        /** Recarga de quickshell conservando el traspaso de recursos nativos.
         *  qs -c bar ipc call island reload */
        function reload(): bool { Quickshell.reload(false); return true; }
    }

    // ---- reserve (struts, click-through) ----
    Variants {
        model: Quickshell.screens

        IslandReserve {  }
    }

    // ---- overlay (Pill + mask tri-estado) ----
    Variants {
        model: Quickshell.screens

        IslandOverlay { router: navigation }
    }

}
