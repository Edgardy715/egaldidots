-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ══════════════════════════════════════════════
--  NÚMEROS DE LÍNEA
-- ══════════════════════════════════════════════
vim.opt.number = true -- muestra el número de línea actual
vim.opt.relativenumber = true -- líneas arriba/abajo muestran la distancia

-- ══════════════════════════════════════════════
--  INDENTACIÓN
-- ══════════════════════════════════════════════
vim.opt.tabstop = 2 -- un tab equivale a 2 espacios visualmente
vim.opt.shiftwidth = 2 -- al indentar con >> o <<, mueve 2 espacios
vim.opt.expandtab = true -- convierte tabs en espacios al escribir
vim.opt.smartindent = true -- indenta automáticamente al abrir llaves/bloques

-- ══════════════════════════════════════════════
--  SCROLL Y CURSOR
-- ══════════════════════════════════════════════
vim.opt.scrolloff = 8 -- mantiene 8 líneas de contexto arriba/abajo del cursor
vim.opt.sidescrolloff = 8 -- igual pero horizontal
vim.opt.cursorline = true -- resalta la línea donde está el cursor

-- ══════════════════════════════════════════════
--  BÚSQUEDA
-- ══════════════════════════════════════════════
vim.opt.ignorecase = true -- búsqueda sin distinguir mayúsculas
vim.opt.smartcase = true -- pero si escribes con mayúscula, sí las respeta

-- ══════════════════════════════════════════════
--  CLIPBOARD
-- ══════════════════════════════════════════════
vim.opt.clipboard = "unnamedplus" -- comparte clipboard con el sistema (Wayland/X11)

-- ══════════════════════════════════════════════
--  VISUAL
-- ══════════════════════════════════════════════
vim.opt.colorcolumn = "" -- línea guía en la columna 100
vim.opt.signcolumn = "yes" -- siempre muestra la columna de signos (errores, git, etc)
vim.opt.termguicolors = true -- colores de 24 bits en la terminal
vim.opt.wrap = false -- no parte líneas largas visualmente

-- ══════════════════════════════════════════════
--  SPLITS
-- ══════════════════════════════════════════════
vim.opt.splitright = true -- nuevos splits verticales abren a la derecha
vim.opt.splitbelow = true -- nuevos splits horizontales abren abajo

-- ══════════════════════════════════════════════
--  ARCHIVOS
-- ══════════════════════════════════════════════
vim.opt.undofile = true -- guarda el historial de deshacer aunque cierres nvim
vim.opt.swapfile = false -- no crea archivos .swp

-- ══════════════════════════════════════════════
--  DETECCIÓN DE ARCHIVOS DE RED (CISCO / FORTINET)
-- ══════════════════════════════════════════════
vim.filetype.add({
  extension = {
    ios = "cisco",
    fgt = "fortios",
  },
  pattern = {
    [".*fgt.*%.conf"] = "fortios",
    [".*forti.*%.conf"] = "fortios",
    [".*running%-config"] = "cisco",
  },
})
