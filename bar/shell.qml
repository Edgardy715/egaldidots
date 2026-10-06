//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma IconTheme "hicolor"
import QtQuick
import Quickshell
import Quickshell.Io
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
 * para keybinds. Un monitor vacío resuelve al foco. ShellRuntime integra
 * los servicios del escritorio con el router.
 */
ShellRoot {
    id: root

    settings.watchFiles: true

    SurfaceRouter {
        id: navigation
    }

    ShellRuntime { router: navigation }

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
