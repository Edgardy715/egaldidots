return {
  {
    "nvim-mini/mini.nvim",
    event = "LazyFile",
    config = function()
      local indentscope = require("mini.indentscope")

      indentscope.setup({
        symbol = "│",
        options = { try_as_border = true },
        draw = {
          delay = 0,
          animation = indentscope.gen_animation.none(),
        },
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "snacks_dashboard",
          "neo-tree",
          "lazy",
          "mason",
          "help",
          "terminal",
          "toggleterm",
          "Trouble",
          "trouble",
          "lspinfo",
          "man",
          "checkhealth",
          "qf",
          "notify",
          "gitcommit",
          "lazygit",
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    optional = true,
    opts = {
      scope = {
        enabled = false,
      },
    },
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      indent = {
        scope = {
          enabled = false,
        },
      },
    },
  },
}
