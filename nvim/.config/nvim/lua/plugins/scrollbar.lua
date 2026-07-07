return {
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    config = function()
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
