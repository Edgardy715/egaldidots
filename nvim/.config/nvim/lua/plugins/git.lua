return {
  -- gitsigns: change indicators in the margin
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
      -- Shows the blame for the current line as you type
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500, -- shows up after 500ms without moving the cursor
      },
    },
  },

  -- lazygit: full visual git client
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
