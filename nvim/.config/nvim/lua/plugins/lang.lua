return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
        pyright = {
          settings = {
            python = {
              pythonPath = "/usr/bin/python3",
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
                diagnosticSeverityOverrides = {
                  reportWildcardImportFromLibrary = "none",
                  reportUndefinedVariable = "none",
                  reportMissingModuleSource = "none",
                },
              },
            },
          },
        },
      },
    },
  },

  -- Formateo automático al guardar
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        sh = { "shfmt" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
  },
}
