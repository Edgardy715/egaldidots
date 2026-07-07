-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ─────────────────────────────────────────────────────────────
-- LEE LOS COLORES DE PYWAL
-- Devuelve una tabla indexada desde 0 con los colores de:
--   ~/.cache/wal/colors
-- ─────────────────────────────────────────────────────────────
local function get_wal_colors()
  local wal = {}
  local f = io.open(os.getenv("HOME") .. "/.cache/wal/colors", "r")
  if f then
    local i = 0
    for line in f:lines() do
      wal[i] = line
      i = i + 1
    end
    f:close()
  end
  return wal
end

-- ─────────────────────────────────────────────────────────────
-- HIGHLIGHTS PERSONALIZADOS GENERALES
-- Texto neutro legible + keywords/tipos/strings con colores pywal
-- ─────────────────────────────────────────────────────────────
local function apply_wal_highlights()
  local wal = get_wal_colors()

  vim.api.nvim_set_hl(0, "Normal", { fg = "#c0caf5" })
  vim.api.nvim_set_hl(0, "@variable", { fg = "#c0caf5" })
  vim.api.nvim_set_hl(0, "@variable.builtin", { fg = "#b4c2f0" })
  vim.api.nvim_set_hl(0, "Identifier", { fg = "#c0caf5" })

  vim.api.nvim_set_hl(0, "@function", { fg = "#e0e0f0", bold = true })
  vim.api.nvim_set_hl(0, "@function.call", { fg = "#d0d0e8" })
  vim.api.nvim_set_hl(0, "@method", { fg = "#e0e0f0", bold = true })
  vim.api.nvim_set_hl(0, "@method.call", { fg = "#d0d0e8" })

  vim.api.nvim_set_hl(0, "Comment", { fg = "#6a6a8a", italic = true })
  vim.api.nvim_set_hl(0, "@comment", { fg = "#6a6a8a", italic = true })

  vim.api.nvim_set_hl(0, "Keyword", { fg = wal[1], bold = true })
  vim.api.nvim_set_hl(0, "@keyword", { fg = wal[1], bold = true })
  vim.api.nvim_set_hl(0, "@keyword.function", { fg = wal[2], bold = true })
  vim.api.nvim_set_hl(0, "@keyword.return", { fg = wal[4], bold = true })

  vim.api.nvim_set_hl(0, "String", { fg = wal[2] })
  vim.api.nvim_set_hl(0, "@string", { fg = wal[2] })

  vim.api.nvim_set_hl(0, "Number", { fg = wal[3] })
  vim.api.nvim_set_hl(0, "@number", { fg = wal[3] })
  vim.api.nvim_set_hl(0, "@float", { fg = wal[3] })

  vim.api.nvim_set_hl(0, "Type", { fg = wal[5] })
  vim.api.nvim_set_hl(0, "@type", { fg = wal[5] })
  vim.api.nvim_set_hl(0, "@type.builtin", { fg = wal[4] })

  vim.api.nvim_set_hl(0, "Constant", { fg = wal[6] })
  vim.api.nvim_set_hl(0, "@constant", { fg = wal[6] })
  vim.api.nvim_set_hl(0, "@constant.builtin", { fg = wal[5] })

  vim.api.nvim_set_hl(0, "@operator", { fg = "#8888aa" })
  vim.api.nvim_set_hl(0, "@punctuation", { fg = "#7a7a9a" })
end

-- ─────────────────────────────────────────────────────────────
-- HIGHLIGHTS PARA SNACKS DASHBOARD
-- Más jerarquía visual:
--   - header más tenue
--   - acciones más claras
--   - footer más discreto
-- ─────────────────────────────────────────────────────────────
local function apply_dashboard_highlights()
  local wal = get_wal_colors()

  local accent = wal[1] or "#d79921"
  local accent2 = wal[2] or "#89b482"
  local accent3 = wal[4] or "#7daea3"
  local fg = "#d8dee9"
  local muted = "#a7b0c0"
  local faint = "#7b8496"

  vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = muted, bold = false })
  vim.api.nvim_set_hl(0, "SnacksDashboardKey", { fg = accent3, bold = true })
  vim.api.nvim_set_hl(0, "SnacksDashboardDesc", { fg = fg })
  vim.api.nvim_set_hl(0, "SnacksDashboardIcon", { fg = accent2 })
  vim.api.nvim_set_hl(0, "SnacksDashboardSpecial", { fg = accent, bold = true })
  vim.api.nvim_set_hl(0, "SnacksDashboardFooter", { fg = faint, italic = true })
  vim.api.nvim_set_hl(0, "SnacksDashboardDir", { fg = faint })
  vim.api.nvim_set_hl(0, "SnacksDashboardFile", { fg = fg })
end

-- ─────────────────────────────────────────────────────────────
-- HIGHLIGHTS PARA NVIM-NOTIFY
-- Reaplica colores de notify derivados de pywal
-- ─────────────────────────────────────────────────────────────
local function apply_notify_highlights()
  local wal = get_wal_colors()

  local bg = wal[8] or "#3b4252"
  local fg = "#e5e9f0"
  local info = wal[4] or "#81a1c1"
  local warn = wal[3] or "#ebcb8b"
  local err = wal[1] or "#bf616a"
  local ok = wal[2] or "#a3be8c"

  vim.api.nvim_set_hl(0, "NotifyBackground", { bg = "NONE" })

  vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = info, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = warn, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = err, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = ok, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { fg = ok, bg = "NONE" })

  vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = info, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = warn, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = err, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyDEBUGIcon", { fg = ok, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NotifyTRACEIcon", { fg = ok, bg = "NONE" })

  vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = info, bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = warn, bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = err, bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { fg = ok, bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "NotifyTRACETitle", { fg = ok, bg = "NONE", bold = true })

  vim.api.nvim_set_hl(0, "NotifyINFOBody", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "NotifyWARNBody", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "NotifyERRORBody", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "NotifyTRACEBody", { fg = fg, bg = bg })
end

-- ─────────────────────────────────────────────────────────────
-- HIGHLIGHTS PARA SATELLITE (SCROLLBAR)
-- Reaplica colores del scrollbar y sus marcadores
-- ─────────────────────────────────────────────────────────────
local function apply_satellite_highlights()
  local wal = get_wal_colors()

  local bg = wal[8] or "#4c566a"
  local accent = wal[1] or "#d79921"
  local accent2 = wal[2] or "#89b482"
  local accent3 = wal[4] or "#7daea3"
  local fg = "#d8dee9"

  vim.api.nvim_set_hl(0, "SatelliteBar", { fg = bg, bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteCursor", { fg = fg, bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteSearch", { fg = accent, bg = "NONE" })

  vim.api.nvim_set_hl(0, "SatelliteDiagnosticError", { fg = wal[1] or "#bf616a", bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteDiagnosticWarn", { fg = wal[3] or "#ebcb8b", bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteDiagnosticInfo", { fg = accent3, bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteDiagnosticHint", { fg = accent2, bg = "NONE" })

  vim.api.nvim_set_hl(0, "SatelliteGitSignsAdd", { fg = accent2, bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteGitSignsChange", { fg = accent3, bg = "NONE" })
  vim.api.nvim_set_hl(0, "SatelliteGitSignsDelete", { fg = wal[1] or "#bf616a", bg = "NONE" })
end

-- ─────────────────────────────────────────────────────────────
-- REFRESCA PLUGINS/UI QUE NECESITAN REAPLICACIÓN ACTIVA
-- ─────────────────────────────────────────────────────────────
local function refresh_dynamic_ui()
  if _G.reload_lualine then
    _G.reload_lualine()
  end

  -- satellite.nvim puede quedarse desincronizado tras cambios visuales;
  -- su comando recomendado para resincronizar es :SatelliteRefresh
  pcall(vim.cmd, "SatelliteRefresh")

  -- Redibuja statusline/winbar
  vim.cmd("redrawstatus")
end

-- ─────────────────────────────────────────────────────────────
-- APLICA TODOS LOS HIGHLIGHTS PERSONALIZADOS
-- Punto central de estilo visual
-- ─────────────────────────────────────────────────────────────
local function apply_all_custom_highlights()
  apply_wal_highlights()
  apply_dashboard_highlights()
  apply_notify_highlights()
  apply_satellite_highlights()
end

-- ─────────────────────────────────────────────────────────────
-- RECARGA VISUAL COMPLETA DESDE PYWAL
-- Flujo:
--   1. Limpia caché de pywal16
--   2. Relee ~/.cache/wal/colors
--   3. Aplica colorscheme pywal16
--   4. Reaplica todos los highlights personalizados
--   5. Refresca lualine y satellite
-- ─────────────────────────────────────────────────────────────
local function full_wal_reload()
  package.loaded["pywal16"] = nil
  require("pywal16").setup()
  vim.cmd("colorscheme pywal16")

  apply_all_custom_highlights()
  refresh_dynamic_ui()
end

-- ─────────────────────────────────────────────────────────────
-- Al cambiar colorscheme:
-- reaplica todos los highlights personalizados y refresca UI.
-- No llamamos full_wal_reload aquí para evitar loops, porque
-- full_wal_reload ejecuta :colorscheme y eso dispararía este
-- mismo autocmd otra vez.
-- ─────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    apply_all_custom_highlights()
    refresh_dynamic_ui()
  end,
})

-- ─────────────────────────────────────────────────────────────
-- Al recibir SIGUSR1 desde el wallpaper picker:
-- recarga completa de pywal + highlights + UI
-- Ejemplo:
--   pkill -USR1 nvim
-- ─────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = full_wal_reload,
})
