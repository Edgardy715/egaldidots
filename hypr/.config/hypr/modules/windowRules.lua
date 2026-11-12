------------------------------
--- WINDOWS AND WORKSPACES ---
------------------------------
-- Ver https://wiki.hypr.land/Configuring/Basics/Window-Rules

-- Ignorar solicitudes de maximizar de todas las apps.
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Arregla algunos problemas de arrastre con XWayland.
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Ventana de hyprland-run flotante en la parte inferior.
hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

-- Efecto de vidrio para las capas. Mismo patrón que en hyprlang.

-- Efecto de vidrio (blur compositor) para Isla quickshell (dynamic island · píldora top).
-- Namespace = quickshell.island (WlrLayershell.namespace en shell.qml).
-- Flags.glassAlpha 0.34 → 66% wallpaper se ve blurred; ignore_alpha 0.15 = blurea todo
-- pixel con alpha > 0.15 (el glass 0.34 entra; los bordes AA/áreas vacías alpha 0 no).
hl.layer_rule({ match = { namespace = "quickshell.island" }, blur = true, ignore_alpha = 0.15 })

-- Toast Isla (popups de notificación · ventana aparte, NO morfea la pill).
-- Namespace = quickshell.notiftoast (WlrLayershell.namespace en Toast.qml).
hl.layer_rule({ match = { namespace = "quickshell.notiftoast" }, blur = true, ignore_alpha = 0.15 })

-- Overview Isla (tabs · mini-ventanas vivas): morpha la PROPIA pill → mismo
-- namespace quickshell.island de arriba (ya blurreado). No hace falta layerrule aparte.

-- Perfil de opacidad por tipo de app (activa inactiva); único sitio donde se define.
-- Terminal: la fija Kitty (background_opacity) y la responsable del blur es hyprglass.
-- Navegador y editores: opacos, sin regla.
local OPACITY = {
    chat  = { classes = "^(vesktop)$",             value = "0.90 0.85" },
    files = { classes = "^(thunar)$",              value = "0.88 0.82" },
    music = { classes = "^(Spotify|spotify)$",     value = "0.88 override 0.84 override 1.0 override" },
}
for kind, p in pairs(OPACITY) do
    hl.window_rule({ name = kind .. "-glass", match = { class = p.classes }, opacity = p.value })
end

-- pinentry: mantener el foco (arregla el selector de contraseñas que le roba
-- el foco a la ventana que pide la clave).
hl.window_rule({
    name = "pinentry-stay-focused",
    match = { class = "(pinentry-)(.*)" },
    stay_focused = true,
})

-- Diálogos de archivos (GTK/XWayland "Open/Save/Select"): flotantes y centrados
-- para que no se queden pegados al tile cuando los llama una app.
hl.window_rule({
    name = "file-dialogs-float",
    match = { title = "^(Open File|Save As|Save File|Select File|Select Files|Choose File)" },
    float = true,
    center = true,
})

-- Los diálogos modales reales se abren separados y centrados.
hl.window_rule({ name = "modal-dialogs", match = { modal = true }, float = true, center = true })
