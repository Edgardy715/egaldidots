return {
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      local colors = require("config.isla_palette").colors()

      local bg = colors.surface_variant or "#3b4252"
      local fg = colors.on_surface
      local info = colors.primary or "#81a1c1"
      local warn = colors.tertiary or "#ebcb8b"
      local err = colors.error or "#bf616a"
      local ok = colors.secondary or "#a3be8c"

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
