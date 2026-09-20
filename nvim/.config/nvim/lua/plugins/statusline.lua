return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      local function get_wal()
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
        return wal
      end

      local function is_dashboard()
        return vim.bo.filetype == "snacks_dashboard"
      end

      local function has_file()
        return vim.fn.expand("%:t") ~= ""
      end

      local function build_theme()
        local wal = get_wal()
        local soft = wal[8] or "#4c566a"

        return {
          normal = {
            a = { fg = "#ffffff", bg = wal[1], gui = "bold" },
            b = { fg = "#f5f5f5", bg = soft },
            c = { fg = "#e8e8e8", bg = "none" },
          },
          insert = {
            a = { fg = "#ffffff", bg = wal[2], gui = "bold" },
            b = { fg = "#f5f5f5", bg = soft },
            c = { fg = "#e8e8e8", bg = "none" },
          },
          visual = {
            a = { fg = "#ffffff", bg = wal[3], gui = "bold" },
            b = { fg = "#f5f5f5", bg = soft },
            c = { fg = "#e8e8e8", bg = "none" },
          },
          replace = {
            a = { fg = "#ffffff", bg = wal[4], gui = "bold" },
            b = { fg = "#f5f5f5", bg = soft },
            c = { fg = "#e8e8e8", bg = "none" },
          },
          command = {
            a = { fg = "#ffffff", bg = wal[5], gui = "bold" },
            b = { fg = "#f5f5f5", bg = soft },
            c = { fg = "#e8e8e8", bg = "none" },
          },
          inactive = {
            a = { fg = "#aaaaaa", bg = "none" },
            b = { fg = "#aaaaaa", bg = "none" },
            c = { fg = "#aaaaaa", bg = "none" },
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
