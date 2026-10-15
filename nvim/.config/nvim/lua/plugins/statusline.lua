return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      local function get_colors()
        return require("config.isla_palette").colors()
      end

      local function is_dashboard()
        return vim.bo.filetype == "snacks_dashboard"
      end

      local function has_file()
        return vim.fn.expand("%:t") ~= ""
      end

      local function build_theme()
        local colors = get_colors()
        local soft = colors.surface_variant or "#4c566a"

        return {
          normal = {
            a = { fg = colors.on_primary, bg = colors.primary, gui = "bold" },
            b = { fg = colors.on_surface, bg = soft },
            c = { fg = colors.on_surface, bg = "none" },
          },
          insert = {
            a = { fg = colors.on_secondary, bg = colors.secondary, gui = "bold" },
            b = { fg = colors.on_surface, bg = soft },
            c = { fg = colors.on_surface, bg = "none" },
          },
          visual = {
            a = { fg = colors.on_tertiary, bg = colors.tertiary, gui = "bold" },
            b = { fg = colors.on_surface, bg = soft },
            c = { fg = colors.on_surface, bg = "none" },
          },
          replace = {
            a = { fg = colors.on_error, bg = colors.error, gui = "bold" },
            b = { fg = colors.on_surface, bg = soft },
            c = { fg = colors.on_surface, bg = "none" },
          },
          command = {
            a = { fg = colors.on_tertiary, bg = colors.tertiary, gui = "bold" },
            b = { fg = colors.on_surface, bg = soft },
            c = { fg = colors.on_surface, bg = "none" },
          },
          inactive = {
            a = { fg = colors.on_surface_variant, bg = "none" },
            b = { fg = colors.on_surface_variant, bg = "none" },
            c = { fg = colors.on_surface_variant, bg = "none" },
          },
        }
      end

      local function get_opts()
        return {
          options = {
            theme = build_theme(),
            component_separators = { left = "", right = "" },
            section_separators = { left = "", right = "" },
            globalstatus = true,
            disabled_filetypes = {
              winbar = {},
              statusline = {},
            },
          },
          sections = {
            lualine_a = {
              {
                "mode",
                separator = { left = "", right = "" },
                right_padding = 2,
              },
            },

            lualine_b = {
              {
                "branch",
                icon = "",
                cond = function()
                  return not is_dashboard() and has_file()
                end,
              },
              {
                "diff",
                symbols = { added = " ", modified = " ", removed = " " },
                cond = function()
                  return not is_dashboard() and has_file()
                end,
              },
            },

            lualine_c = {
              {
                "filename",
                path = 1,
                symbols = { modified = "  ", readonly = " ", unnamed = " " },
                cond = function()
                  return not is_dashboard()
                end,
              },
              {
                function()
                  return "  snacks dashboard"
                end,
                cond = is_dashboard,
              },
            },

            lualine_x = {
              {
                "diagnostics",
                sources = { "nvim_lsp" },
                symbols = { error = " ", warn = " ", info = " ", hint = " " },
                cond = function()
                  return not is_dashboard()
                end,
              },
              {
                "filetype",
                cond = function()
                  return not is_dashboard() and has_file()
                end,
              },
              {
                "encoding",
                cond = function()
                  return not is_dashboard() and has_file()
                end,
              },
            },

            lualine_y = {
              {
                "progress",
                cond = function()
                  return not is_dashboard()
                end,
              },
              {
                function()
                  return " " .. math.floor(vim.fn.line(".") / math.max(vim.fn.line("$"), 1) * 100) .. "%"
                end,
                cond = is_dashboard,
              },
            },

            lualine_z = {
              {
                function()
                  return os.date("%H:%M")
                end,
                separator = { left = "", right = "" },
                padding = { left = 1, right = 1 },
              },
            },
          },

          inactive_sections = {
            lualine_c = {
              { "filename", path = 1 },
            },
            lualine_x = { "location" },
          },
        }
      end

      require("lualine").setup(get_opts())

      _G.reload_lualine = function()
        require("lualine").setup(get_opts())
        vim.cmd("redrawstatus")
      end
    end,
  },
}
