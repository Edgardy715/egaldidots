local M = {}

local fallback = {
  background = "#1e1e2e", on_background = "#cdd6f4", surface = "#1e1e2e",
  on_surface = "#cdd6f4", surface_variant = "#45475a", on_surface_variant = "#bac2de",
  primary = "#89b4fa", on_primary = "#1e1e2e", secondary = "#a6e3a1",
  on_secondary = "#1e1e2e", tertiary = "#f5c2e7", on_tertiary = "#1e1e2e",
  error = "#f38ba8", on_error = "#1e1e2e", outline = "#9399b2",
}

function M.colors()
  local cache = vim.env.XDG_CACHE_HOME or ((vim.env.HOME or "") .. "/.cache")
  local path = cache .. "/matugen/palette.json"
  local file = io.open(path, "r")
  if not file then return fallback end
  local content = file:read("*a")
  file:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or data.version ~= 1 or type(data.colors) ~= "table" then
    return fallback
  end
  local result = vim.deepcopy(fallback)
  for role in pairs(fallback) do
    local value = data.colors[role]
    if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then result[role] = value end
  end
  return result
end

return M
