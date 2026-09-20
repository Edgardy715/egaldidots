-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ══════════════════════════════════════════════
--  LINE NUMBERS
-- ══════════════════════════════════════════════
vim.opt.number = true -- shows the current line number
vim.opt.relativenumber = true -- lines above/below show their distance

-- ══════════════════════════════════════════════
--  INDENTATION
-- ══════════════════════════════════════════════
vim.opt.tabstop = 2 -- a tab equals 2 spaces visually
vim.opt.shiftwidth = 2 -- indenting with >> or << shifts 2 spaces
vim.opt.expandtab = true -- converts tabs into spaces while typing
vim.opt.smartindent = true -- auto-indents on opening braces/blocks

-- ══════════════════════════════════════════════
--  SCROLL & CURSOR
-- ══════════════════════════════════════════════
vim.opt.scrolloff = 8 -- keeps 8 lines of context above/below the cursor
vim.opt.sidescrolloff = 8 -- same but horizontal
vim.opt.cursorline = true -- highlights the line the cursor is on

-- ══════════════════════════════════════════════
--  SEARCH
-- ══════════════════════════════════════════════
vim.opt.ignorecase = true -- case-insensitive search
vim.opt.smartcase = true -- but uppercase input is still case-sensitive

-- ══════════════════════════════════════════════
--  CLIPBOARD
-- ══════════════════════════════════════════════
vim.opt.clipboard = "unnamedplus" -- shares the clipboard with the system (Wayland/X11)

-- ══════════════════════════════════════════════
--  VISUAL
-- ══════════════════════════════════════════════
vim.opt.colorcolumn = "" -- no fixed-width guide column
vim.opt.signcolumn = "yes" -- always shows the sign column (errors, git, etc)
vim.opt.termguicolors = true -- 24-bit colors in the terminal
vim.opt.wrap = false -- don't visually wrap long lines

-- ══════════════════════════════════════════════
--  SPLITS
-- ══════════════════════════════════════════════
vim.opt.splitright = true -- new vertical splits open to the right
vim.opt.splitbelow = true -- new horizontal splits open below

-- ══════════════════════════════════════════════
--  FILES
-- ══════════════════════════════════════════════
vim.opt.undofile = true -- keeps the undo history even after closing nvim
vim.opt.swapfile = false -- doesn't create .swp files

-- ══════════════════════════════════════════════
--  NETWORK FILE TYPE DETECTION (CISCO / FORTINET)
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
