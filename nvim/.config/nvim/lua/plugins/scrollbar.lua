return {
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    config = function()
      local colors = require("config.isla_palette").colors()

      local bg = colors.surface_variant or "#4c566a"
      local accent = colors.error or "#d79921"
      local accent2 = colors.secondary or "#89b482"
      local accent3 = colors.primary or "#7daea3"
      local fg = colors.on_surface

      vim.api.nvim_set_hl(0, "SatelliteBar", { fg = bg, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteCursor", { fg = fg, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteSearch", { fg = accent, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteDiagnosticError", { fg = colors.error or "#bf616a", bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteDiagnosticWarn", { fg = colors.tertiary or "#ebcb8b", bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteDiagnosticInfo", { fg = accent3, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteDiagnosticHint", { fg = accent2, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteGitSignsAdd", { fg = accent2, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteGitSignsChange", { fg = accent3, bg = "NONE" })
      vim.api.nvim_set_hl(0, "SatelliteGitSignsDelete", { fg = colors.error or "#bf616a", bg = "NONE" })

      require("satellite").setup({
        current_only = false,
        winblend = 0,
        zindex = 40,
        excluded_filetypes = {
          "snacks_dashboard",
          "neo-tree",
          "lazy",
          "mason",
          "help",
          "terminal",
          "toggleterm",
          "Trouble",
          "trouble",
          "qf",
          "prompt",
          "nofile",
        },
        handlers = {
          cursor = {
            enable = true,
          },
          search = {
            enable = true,
          },
          diagnostic = {
            enable = true,
          },
          gitsigns = {
            enable = true,
          },
          marks = {
            enable = false,
          },
        },
      })
    end,
  },
}
