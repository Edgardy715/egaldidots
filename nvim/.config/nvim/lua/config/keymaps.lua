-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Correr script actual según el tipo de archivo
vim.keymap.set("n", "<leader>r", function()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")

  local runners = {
    python = "python3",
    sh = "bash",
  }

  local runner = runners[ft]
  if not runner then
    vim.notify("No hay runner configurado para: " .. ft, vim.log.levels.WARN)
    return
  end

  -- Carga toggleterm si no está cargado
  require("toggleterm")
  local Terminal = require("toggleterm.terminal").Terminal
  local term = Terminal:new({
    cmd = runner .. " " .. file,
    direction = "horizontal",
    close_on_exit = false, -- para que puedas ver el output
    on_open = function(t)
      vim.cmd("startinsert!")
    end,
  })
  term:toggle()
end, { desc = "Correr archivo actual" })
