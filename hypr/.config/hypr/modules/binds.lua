--------------------
---     BINDS     ---
--------------------
-- Ver https://wiki.hypr.land/Configuring/Basics/Binds
--
-- Cada atajo editable se registra con B(id, etiqueta, grupo, teclas, acción, opciones).
-- Los IDs son estables: ~/.config/hypr/binds.user.json los usa para remapear o
-- desactivar atajos desde los ajustes de Isla. Al cargar, se escribe el catálogo
-- (con tecla por defecto y tecla activa) en $XDG_RUNTIME_DIR/isla-binds-catalog.json.

local mainMod = "SUPER" -- Tecla "Windows" como modificador principal
local isla = require("modules.isla")
local home = os.getenv("HOME")
local userPath = home .. "/.config/hypr/binds.user.json"
local okUser, binds_user = pcall(require, "modules.binds_user")
local userData = {}
local function loadOverrides()
    userData = {}
    if not okUser then return {} end
    local ok, data = pcall(binds_user.loadAll, userPath)
    if ok and type(data) == "table" then userData = data end
    return type(userData.binds) == "table" and userData.binds or {}
end
local overrides = loadOverrides()
local catalog = {}
local customs = {}

-- Command text for the catalog (the shortcut explorer and settings show it).
local commands = setmetatable({}, { __mode = "k" })
local function exec(cmd)
    local d = hl.dsp.exec_cmd(cmd)
    commands[d] = cmd
    return d
end

local function resolve(d)
    local o = overrides[d.id]
    local active, enabled = d.default, true
    if type(o) == "table" then
        if o.enabled == false then enabled = false
        elseif type(o.key) == "string" and o.key ~= "" then active = o.key end
    end
    return active, enabled
end

-- Registra (o recoloca) un atajo según su override. Quita el anterior si ya existía.
local function place(d)
    local active, enabled = resolve(d)
    if d.handle then pcall(function() d.handle:remove() end); d.handle = nil end
    if enabled then
        local ok, h = pcall(hl.bind, active, d.dsp, d.options)
        if not ok and active ~= d.default then
            active = d.default
            ok, h = pcall(hl.bind, d.default, d.dsp, d.options)
        end
        if ok then d.handle = h else enabled = false end
    end
    d.key, d.enabled = active, enabled
end

local function B(id, label, group, keys, dsp, opts)
    local options = {}
    for k, v in pairs(opts or {}) do options[k] = v end
    options.description = "isla:" .. id
    local d = { id = id, label = label, group = group, default = keys, dsp = dsp, options = options, cmd = commands[dsp] or "" }
    place(d)
    catalog[#catalog + 1] = d
end

local function writeCatalog()
    local function q(s) return '"' .. tostring(s):gsub('[\\"]', "\\%0"):gsub("\n", "\\n") .. '"' end
    local rows = {}
    for _, b in ipairs(catalog) do
        rows[#rows + 1] = string.format('{"id":%s,"label":%s,"group":%s,"default":%s,"key":%s,"enabled":%s,"cmd":%s}',
            q(b.id), q(b.label), q(b.group), q(b.default), q(b.key), tostring(b.enabled), q(b.cmd or ""))
    end
    for _, c in ipairs(customs) do
        rows[#rows + 1] = string.format('{"id":%s,"label":%s,"group":"Personalizados","default":%s,"key":%s,"enabled":%s,"cmd":%s,"custom":true}',
            q(c.id), q(c.label), q(c.key), q(c.key), tostring(c.enabled), q(c.cmd))
    end
    local dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    local path = dir .. "/isla-binds-catalog.json"
    local f = io.open(path .. ".tmp", "w")
    if not f then return end
    f:write('{"version":1,"binds":[' .. table.concat(rows, ",") .. ']}')
    f:close()
    os.rename(path .. ".tmp", path)
end

-- Aplicaciones
B("app.browser", "Navegador", "Aplicaciones", mainMod .. " + B", exec("zen-browser"))
B("app.terminal", "Terminal", "Aplicaciones", mainMod .. " + Return", exec(terminal))
B("window.close", "Cerrar ventana", "Ventanas", mainMod .. " + Q", hl.dsp.window.close())
B("isla.session", "Sesión", "Isla", mainMod .. " + M", exec('qs -c bar ipc call island session ""'))
B("app.files", "Archivos", "Aplicaciones", mainMod .. " + E", exec(fileManager))
B("window.float", "Flotar ventana", "Ventanas", mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))

-- Isla (quickshell): lanzador, wallpaper, notificaciones, utilidades, red y mezclador.
B("isla.launcher", "Lanzador", "Isla", mainMod .. " + S", exec('qs -c bar ipc call island launcher ""'))
B("isla.wallpaper", "Fondos", "Isla", mainMod .. " + W", exec('qs -c bar ipc call island wallpaper ""'))
B("isla.notifs", "Notificaciones", "Isla", mainMod .. " + N", exec('qs -c bar ipc call island notifs ""'))
B("isla.utils", "Utilidades", "Isla", mainMod .. " + U", exec('qs -c bar ipc call island utils ""'))
B("isla.connectivity", "Conectividad", "Isla", mainMod .. " + C", exec('qs -c bar ipc call island connectivity ""'))
B("isla.mixer", "Mezclador", "Isla", mainMod .. " + A", exec('qs -c bar ipc call island mixer ""'))
B("isla.settings", "Ajustes", "Isla", mainMod .. " + I", exec('qs -c bar ipc call island settings'))
B("isla.shortcuts", "Explorador de atajos", "Isla", mainMod .. " + K", exec('qs -c bar ipc call island shortcuts ""'))

-- ScrollOverview manual; both keys remain available inside its own submap.
local workspaceMotion = require("modules.workspace_motion")
B("overview.toggle", "Vista general", "Espacios", mainMod .. " + Tab", exec(isla.script("scrolloverview-toggle.sh")), { submap_universal = true })
B("overview.isla", "Vista general de Isla", "Espacios", mainMod .. " + SHIFT + Tab", exec(isla.script("scrolloverview-isla.sh")), { submap_universal = true })

-- Teclas internas del submap: no editables.
hl.define_submap("scrolloverview", function()
    hl.bind("left",   function() workspaceMotion.navigate("left") end)
    hl.bind("right",  function() workspaceMotion.navigate("right") end)
    hl.bind("up",     function() workspaceMotion.navigate("up") end)
    hl.bind("down",   function() workspaceMotion.navigate("down") end)
    hl.bind("return", function() workspaceMotion.overview("off") end)
    hl.bind("KP_Enter", function() workspaceMotion.overview("off") end)
    hl.bind("escape", function() workspaceMotion.overview("off") end)
    hl.bind("mouse:272", function() workspaceMotion.selectClick() end, { mouse = true, ignore_mods = true })
end)

-- Columnas scrolling
B("layout.colresize", "Cambiar ancho de columna", "Columnas", mainMod .. " + P", hl.dsp.layout("colresize +conf"))
B("layout.center", "Centrar columna", "Columnas", mainMod .. " + J", hl.dsp.layout("center"))

-- Relanzar quickshell (si se congela). Mata el proceso y lo levanta de nuevo.
local relaunch = [[bash -c "killall qs 2>/dev/null; sleep 0.3; QML_IMPORT_PATH=']] .. isla.root .. [[' ']] .. isla.root .. [[/scripts/start-isla.sh' &"]]
B("isla.relaunch", "Relanzar Isla", "Isla", mainMod .. " + SHIFT + R", exec(relaunch))
-- Atajo de recuperación independiente: útil si una surface queda atrapada.
B("isla.recover", "Relanzar Isla (recuperación)", "Isla", mainMod .. " + ALT + R", exec(relaunch), { submap_universal = true })

-- Layout del teclado: alterna Inglés <-> Español (estilo Win+Espacio)
B("system.keyboard", "Cambiar idioma del teclado", "Sistema", mainMod .. " + space", exec("~/.config/hypr/scripts/kb-toggle.sh"))

-- Portapapeles de Isla (historial compartido de cliphist)
B("isla.clipboard", "Portapapeles", "Isla", mainMod .. " + V", exec('qs -c bar ipc call island clipboard ""'))

-- Screenshot / lockscreen
B("system.shot", "Captura de región", "Sistema", mainMod .. " + SHIFT + S", exec("hyprshot -m region"))
B("system.shot_annotate", "Captura con anotaciones", "Sistema", mainMod .. " + ALT + S", exec("~/.config/hypr/scripts/screenshot-annotate.sh"))
B("system.lock", "Bloquear pantalla", "Sistema", mainMod .. " + L", exec("[ -x ~/.local/bin/isla-lock ] && exec ~/.local/bin/isla-lock || exec hyprlock"))

-- Mover el foco con mainMod + flechas
B("focus.left", "Foco a la izquierda", "Foco", mainMod .. " + left", hl.dsp.layout("focus l"))
B("focus.right", "Foco a la derecha", "Foco", mainMod .. " + right", hl.dsp.layout("focus r"))
B("focus.up", "Foco arriba", "Foco", mainMod .. " + up", hl.dsp.layout("focus u"))
B("focus.down", "Foco abajo", "Foco", mainMod .. " + down", hl.dsp.layout("focus d"))

-- Cambiar workspace con mainMod + [0-9] (0 = workspace 10)
for i = 1, 9 do
    local key = tostring(i)
    B("workspace.go." .. i, "Ir al espacio " .. i, "Espacios", mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    B("workspace.move." .. i, "Mover ventana al espacio " .. i, "Espacios", mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
B("workspace.go.10", "Ir al espacio 10", "Espacios", mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
B("workspace.move.10", "Mover ventana al espacio 10", "Espacios", mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Scroll entre workspaces existentes con el dispatcher nativo.
B("workspace.next", "Espacio siguiente (rueda)", "Espacios", mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
B("workspace.prev", "Espacio anterior (rueda)", "Espacios", mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mover/redimensionar ventanas con mainMod + LMB/RMB arrastrando
B("window.drag", "Arrastrar ventana", "Ventanas", mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
B("window.resize", "Redimensionar ventana", "Ventanas", mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Teclas multimedia del portátil: volumen y brillo (locked + repeating)
B("media.volume_up", "Subir volumen", "Multimedia", "XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
B("media.volume_down", "Bajar volumen", "Multimedia", "XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
B("media.mute", "Silenciar", "Multimedia", "XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
B("media.mic_mute", "Silenciar micrófono", "Multimedia", "XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
B("media.brightness_up", "Subir brillo", "Multimedia", "XF86MonBrightnessUp", exec("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
B("media.brightness_down", "Bajar brillo", "Multimedia", "XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Media keys (requiere playerctl) — locked
B("media.next", "Pista siguiente", "Multimedia", "XF86AudioNext", exec("playerctl next"), { locked = true })
B("media.pause", "Pausa", "Multimedia", "XF86AudioPause", exec("playerctl play-pause"), { locked = true })
B("media.play", "Reproducir", "Multimedia", "XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
B("media.prev", "Pista anterior", "Multimedia", "XF86AudioPrev", exec("playerctl previous"), { locked = true })

-- Scratchpad (special workspace)
B("scratchpad.toggle", "Abrir scratchpad", "Espacios", mainMod .. " + Z", hl.dsp.workspace.toggle_special("scratchpad"))
B("scratchpad.send", "Enviar ventana al scratchpad", "Espacios", mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Gestión de ventanas sin cambiar el layout habitual.
B("window.to_prev_monitor_ws", "Ventana al espacio anterior", "Ventanas", mainMod .. " + SHIFT + Left", hl.dsp.window.move({ workspace = "m-1" }))
B("window.to_next_monitor_ws", "Ventana al espacio siguiente", "Ventanas", mainMod .. " + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1" }))
B("window.fullscreen", "Pantalla completa", "Ventanas", mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
B("window.maximize", "Maximizar", "Ventanas", mainMod .. " + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Reordenar columnas y agrupar/separar sus ventanas.
B("layout.swap_left", "Mover columna a la izquierda", "Columnas", mainMod .. " + CTRL + Left", hl.dsp.layout("swapcol l"))
B("layout.swap_right", "Mover columna a la derecha", "Columnas", mainMod .. " + CTRL + Right", hl.dsp.layout("swapcol r"))
B("layout.consume", "Absorber/expulsar ventana", "Columnas", mainMod .. " + O", hl.dsp.layout("consume_or_expel prev"))
B("layout.promote", "Promover ventana", "Columnas", mainMod .. " + SHIFT + O", hl.dsp.layout("promote"))

-- Atajos creados desde Isla (binds.user.json → "custom"): siempre ejecutan un comando.
local function placeCustom()
    for _, c in ipairs(customs) do
        if c.handle then pcall(function() c.handle:remove() end) end
    end
    customs = {}
    if type(userData.custom) ~= "table" then return end
    for _, c in ipairs(userData.custom) do
        if type(c) == "table" and type(c.id) == "string" and c.id:match("^custom%.%d+$")
                and type(c.key) == "string" and type(c.cmd) == "string" and c.cmd ~= "" then
            local e = { id = c.id, label = tostring(c.label or c.id), key = c.key, cmd = c.cmd, enabled = false }
            if c.enabled ~= false then
                local ok, h = pcall(hl.bind, c.key, hl.dsp.exec_cmd(c.cmd), { description = "isla:" .. c.id })
                if ok then e.handle, e.enabled = h, true end
            end
            customs[#customs + 1] = e
        end
    end
end
placeCustom()

-- Grabador de atajos de Isla: un submapa sin atajos, así cada tecla llega al
-- grabador sin ejecutar nada. Escape sale del submapa y también llega a Isla
-- (non_consuming), de modo que nunca se queda atrapado aunque Isla se cierre.
hl.define_submap("isla_capture", function()
    hl.bind("escape", hl.dsp.submap("reset"), { non_consuming = true, description = "isla:capture.exit" })
end)

-- Llamado por hypr-binds.py vía `hyprctl eval`: aplica sólo los atajos cambiados,
-- sin recargar la configuración (un reload revertiría los ajustes en vivo de Isla).
function isla_rebind()
    overrides = loadOverrides()
    for _, d in ipairs(catalog) do
        local active, enabled = resolve(d)
        if active ~= d.key or enabled ~= d.enabled then place(d) end
    end
    placeCustom()
    writeCatalog()
end

writeCatalog()
