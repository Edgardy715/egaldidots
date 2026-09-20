return {
  {
    "nvim-mini/mini.animate",
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")

      animate.setup({
        cursor = {
          enable = false,
        },

        scroll = {
          enable = false,
        },

        resize = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 90, unit = "total" }),
        },

        open = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 60, unit = "total" }),
        },

        close = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 60, unit = "total" }),
        },
      })
    end,
  },
}
