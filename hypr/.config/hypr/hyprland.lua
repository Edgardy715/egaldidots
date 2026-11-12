---------------------
---  HYPRLAND.LUA  ---
---------------------
-- Entry point principal (reemplaza a hyprland.conf). Carga todos los módulos.
-- Cada require() es un scope separado: un error en un módulo no detiene a los demás.

require("modules.monitors")
require("modules.programs")
require("modules.glass")
require("modules.autostart")
require("modules.envVars")
require("modules.decorations")
require("modules.animations")
require("modules.windowRules")
require("modules.layout")
require("modules.misc")
require("modules.input")
require("modules.binds")

-- Perfil de hardware escrito por el instalador, fuera del paquete Stow.
local hardware = os.getenv("HOME") .. "/.config/hypr/local.hardware.lua"
local f = io.open(hardware, "r")
if f then f:close(); dofile(hardware) end
