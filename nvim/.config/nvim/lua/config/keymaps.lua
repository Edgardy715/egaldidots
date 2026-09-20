-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Run the current file based on its filetype
vim.keymap.set("n", "<leader>r", function()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")

  local runners = {
    python = "python3",
    sh = "bash",
  }

  local runner = runners[ft]
  if not runner then
    vim.notify("No runner configured for: " .. ft, vim.log.levels.WARN)
    return
  end

  -- Load toggleterm if it isn't loaded
  require("toggleterm")
  local Terminal = require("toggleterm.terminal").Terminal
  local term = Terminal:new({
    cmd = runner .. " " .. file,
    direction = "horizontal",
    close_on_exit = false, -- so you can see the output
    on_open = function(t)
      vim.cmd("startinsert!")
    end,
  })
  term:toggle()
end, { desc = "Run current file" })
