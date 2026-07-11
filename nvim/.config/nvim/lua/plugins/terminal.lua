return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = { "<C-t>" },
    opts = {
      size = 15,
      open_mapping = [[<C-t>]], -- Ctrl+t toggles the terminal
      direction = "horizontal", -- opens below the code
      shade_terminals = false, -- no shading, respects your transparency
      persist_size = true, -- remembers the size between uses
      close_on_exit = true, -- closes itself when the process ends
    },
  },
}
