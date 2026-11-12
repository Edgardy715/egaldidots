-- Colores Matugen compartidos por decorations.lua y glass.lua.
-- Lee ~/.cache/matugen/outputs/colors-hyprland.conf al evaluar la config; Matugen
-- ejecuta `hyprctl reload` al cambiar de wallpaper, así que se actualiza solo.
local M = {}
local PATH = os.getenv("HOME") .. "/.cache/matugen/outputs/colors-hyprland.conf"

-- Devuelve "rgba(rrggbbaa)" (formato de gradientes de Hyprland) o el fallback.
function M.color(name, fallback_hex)
    local f = io.open(PATH, "r")
    if not f then return fallback_hex end
    local value = fallback_hex
    for line in f:lines() do
        local varname, val = line:match("^%$([%w_]+)%s*=%s*(.-)%s*$")
        if varname == name and val ~= "" then
            local r, g, b = val:match("rgba?%((%d+),%s*(%d+),%s*(%d+)")
            local hex = val:match("^rgb%((%x%x%x%x%x%x)%)$")
            if hex then value = "rgba(" .. hex .. "ff)" end
            if r then value = string.format("rgba(%02x%02x%02xff)", r, g, b) end
            break
        end
    end
    f:close()
    return value
end

-- "rgba(rrggbbaa)" con otro alpha (dos dígitos hex).
function M.with_alpha(rgba_hex, alpha_hex)
    return rgba_hex:sub(1, #rgba_hex - 3) .. alpha_hex .. ")"
end

-- "rgba(rrggbbaa)" -> entero 0xRRGGBBAA (formato de opciones de hyprglass).
function M.as_int(rgba_hex, alpha)
    local hex = rgba_hex:match("rgba%((%x%x%x%x%x%x)")
    return tonumber(hex, 16) * 256 + (alpha or 255)
end

return M
