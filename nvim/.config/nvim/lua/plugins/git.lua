return {
  -- gitsigns: indicadores de cambios en el margen
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      -- Muestra el blame de la línea actual mientras escribes
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500, -- aparece después de 500ms de no mover el cursor
      },
    },
  },

  -- lazygit: cliente git visual completo
  {
    "kdheepak/lazygit.nvim",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
}
