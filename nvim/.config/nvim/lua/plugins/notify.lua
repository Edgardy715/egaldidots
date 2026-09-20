return {
  {
    "rcarriga/nvim-notify",
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

      local bg = wal[8] or "#3b4252"
      local fg = "#e5e9f0"
      local info = wal[4] or "#81a1c1"
      local warn = wal[3] or "#ebcb8b"
      local err = wal[1] or "#bf616a"
      local ok = wal[2] or "#a3be8c"

      vim.api.nvim_set_hl(0, "NotifyBackground", { bg = "NONE" })

      vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = info, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = warn, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = err, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = ok, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { fg = ok, bg = "NONE" })

      vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = info, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = warn, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = err, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyDEBUGIcon", { fg = ok, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyTRACEIcon", { fg = ok, bg = "NONE" })

      vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = info, bg = "NONE", bold = true })
      vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = warn, bg = "NONE", bold = true })
      vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = err, bg = "NONE", bold = true })
      vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { fg = ok, bg = "NONE", bold = true })
      vim.api.nvim_set_hl(0, "NotifyTRACETitle", { fg = ok, bg = "NONE", bold = true })

      vim.api.nvim_set_hl(0, "NotifyINFOBody", { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, "NotifyWARNBody", { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, "NotifyERRORBody", { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, "NotifyTRACEBody", { fg = fg, bg = bg })

      local notify = require("notify")

      notify.setup({
        render = "default",
        stages = "fade_in_slide_out",
        timeout = 1800,
        top_down = true,
      })

      vim.notify = notify
    end,
  },
}
