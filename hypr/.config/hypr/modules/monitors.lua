-- Cualquier salida: mayor frecuencia soportada, posición y escala automáticas.
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto", vrr = 2 })

local panels = {}
local externalConnected = false
local entries = io.popen("ls -1 /sys/class/drm")
if entries then
    for entry in entries:lines() do
        local name = entry:match("^card%d+%-(.+)$")
        if name then
            if name:match("^eDP%-") or name:match("^LVDS%-") or name:match("^DSI%-") then
                panels[name] = false
            else
                local status = io.open("/sys/class/drm/" .. entry .. "/status", "r")
                if status then
                    if status:read("*l") == "connected" then externalConnected = true end
                    status:close()
                end
            end
        end
    end
    entries:close()
end

local function setPanels(external, force)
    for name, disabled in pairs(panels) do
        if force or disabled ~= external then
            panels[name] = external
            hl.monitor({ output = name, disabled = external,
                mode = "highrr", position = "auto", scale = "auto", vrr = 2 })
        end
    end
end

local function updatePanels()
    local external = false
    for _, monitor in ipairs(hl.get_monitors()) do
        if panels[monitor.name] == nil then external = true; break end
    end
    setPanels(external, false)
end

-- Declarar el estado final antes de reconciliar salidas; no desactivar tras reload.
setPanels(externalConnected, true)
hl.on("monitor.added", updatePanels)
hl.on("monitor.removed", updatePanels)
