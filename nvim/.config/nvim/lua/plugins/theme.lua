return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "pywal16",
    },
  },

  {
    "uZer/pywal16.nvim",
    lazy = false, -- carga al inicio, no lazy
    priority = 1000, -- carga antes que cualquier otro plugin
    config = function()
      local pywal16 = require("pywal16")
      pywal16.setup()

      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      transparent_background = true,
      term_colors = true,
    },
  },
}
