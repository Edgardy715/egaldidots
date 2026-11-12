------------------------------
--- ENVIRONMENT VARIABLES   ---
------------------------------
-- Ver https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables

hl.env("XCURSOR_THEME", "default")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Backend toolkit
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Variables de GPU específicas (NVIDIA, etc.): ~/.config/hypr/local.hardware.lua

-- Priorizar la GPU que tiene una salida externa conectada, conservando todas
-- las demás. Se calcula en cada inicio: card0/card1 pueden cambiar entre boots.
-- El renderer sólo cambia al iniciar una nueva sesión de Hyprland.
local cards, primary = {}, nil
local entries = io.popen("ls -1 /sys/class/drm")
if entries then
    for entry in entries:lines() do
        if entry:match("^card%d+$") then cards[#cards + 1] = "/dev/dri/" .. entry end
        local card, output = entry:match("^(card%d+)%-(.+)$")
        if card and not output:match("^eDP%-") and not output:match("^LVDS%-") and not output:match("^DSI%-") then
            local status = io.open("/sys/class/drm/" .. entry .. "/status", "r")
            if status then
                if status:read("*l") == "connected" and not primary then primary = "/dev/dri/" .. card end
                status:close()
            end
        end
    end
    entries:close()
end
if primary then
    local ordered = { primary }
    for _, card in ipairs(cards) do
        if card ~= primary then ordered[#ordered + 1] = card end
    end
    hl.env("AQ_DRM_DEVICES", table.concat(ordered, ":"))
end

-- AQ_NO_ATOMIC también era un no-op de wlr (WLR_DRM_NO_ATOMIC=0) → eliminado
-- para no arriesgar el modo atómico del backend.

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")