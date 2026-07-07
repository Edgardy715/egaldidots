return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = { "<C-t>" },
    opts = {
      size = 15,
      open_mapping = [[<C-t>]], -- Ctrl+t abre/cierra la terminal
      direction = "horizontal", -- aparece abajo del código
      shade_terminals = false, -- sin sombra, respeta tu transparencia
      persist_size = true, -- recuerda el tamaño entre usos
      close_on_exit = true, -- se cierra sola cuando termina el proceso
    },
  },
}
