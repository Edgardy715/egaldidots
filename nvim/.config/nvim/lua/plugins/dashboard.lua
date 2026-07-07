return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}

      local function read_hat()
        local f = io.open(os.getenv("HOME") .. "/.config/fastfetch/hat.txt", "r")
        if not f then
          return ""
        end
        local content = f:read("*a")
        f:close()
        return content:gsub("%$%d+%s*", "")
      end

      opts.dashboard.preset.header = read_hat()

      opts.dashboard.preset.keys = {
        { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
        { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
        {
          icon = " ",
          key = "c",
          desc = "Config",
          action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })",
        },
        { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
        { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      }

      opts.dashboard.formats = opts.dashboard.formats or {}

      -- Hace que el texto de las acciones se vea un poco más limpio
      opts.dashboard.formats.key = function(item)
        return { { "[", hl = "Comment" }, { item.key, hl = "Special" }, { "]", hl = "Comment" } }
      end

      opts.dashboard.formats.icon = function(item)
        return { { item.icon, hl = "Type" } }
      end

      opts.dashboard.formats.desc = function(item)
        return { { item.desc, hl = "Function" } }
      end

      opts.dashboard.sections = {
        { section = "header", padding = 2 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup", padding = 2 },
      }
    end,
  },
}
