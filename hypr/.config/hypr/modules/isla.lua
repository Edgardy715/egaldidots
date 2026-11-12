-- Raíz del checkout de Isla, resuelta desde ~/.config/quickshell/bar igual que
-- ~/.local/bin/isla: el repositorio puede clonarse en cualquier ruta.
local M = {}
local home = os.getenv("HOME")
local p = io.popen('readlink -f "' .. home .. '/.config/quickshell/bar"')
local bar = p and p:read("*l")
if p then p:close() end
M.root = (bar and bar:match("^(.*)/[^/]+$")) or (home .. "/.config/quickshell")

-- Ruta entrecomillada para exec_cmd a un script de <raíz>/scripts.
function M.script(name)
    return "'" .. M.root .. "/scripts/" .. name .. "'"
end

return M
