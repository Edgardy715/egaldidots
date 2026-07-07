return {
  {
    "SmiteshP/nvim-navic",
    lazy = true,
    opts = {
      highlight = true,
      separator = " 󰁔 ",
      depth_limit = 5,
      icons = {
        File = " ",
        Module = " ",
        Namespace = " ",
        Package = " ",
        Class = " ",
        Method = " ",
        Property = " ",
        Field = " ",
        Constructor = " ",
        Enum = " ",
        Interface = " ",
        Function = "󰊕 ",
        Variable = " ",
        Constant = " ",
        String = " ",
        Number = " ",
        Boolean = " ",
        Array = " ",
        Object = " ",
        Key = " ",
        Null = "󰟢 ",
        EnumMember = " ",
        Struct = " ",
        Event = " ",
        Operator = " ",
        TypeParameter = " ",
      },
      lsp = {
        auto_attach = true,
        preference = nil,
      },
    },
    config = function(_, opts)
      local navic = require("nvim-navic")
      navic.setup(opts)

      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "CursorMoved", "InsertLeave" }, {
        callback = function()
          local ft = vim.bo.filetype
          local bt = vim.bo.buftype

          local excluded_filetypes = {
            snacks_dashboard = true,
            ["neo-tree"] = true,
            lazy = true,
            mason = true,
            help = true,
            toggleterm = true,
            Trouble = true,
            trouble = true,
            qf = true,
            notify = true,
          }

          if bt ~= "" or excluded_filetypes[ft] then
            vim.wo.winbar = ""
            return
          end

          local ok, value = pcall(navic.get_location)
          if ok and value and value ~= "" then
            vim.wo.winbar = " " .. value
          else
            vim.wo.winbar = ""
          end
        end,
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local navic = require("nvim-navic")
      local lsp = opts.servers or {}

      for server, config in pairs(lsp) do
        local old_attach = config.on_attach

        config.on_attach = function(client, bufnr)
          if old_attach then
            old_attach(client, bufnr)
          end

          if client.server_capabilities.documentSymbolProvider then
            navic.attach(client, bufnr)
          end
        end
      end
    end,
  },
}
