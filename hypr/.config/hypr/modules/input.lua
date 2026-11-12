-------------------
---    INPUT     ---
-------------------
-- Ver https://wiki.hypr.land/Configuring/Variables/#input

hl.config({
    input = {
        kb_layout = "us,es", -- Inglés (us) por defecto · Español (es) secundario · Super+Espacio alterna
        follow_mouse = 2, -- Cambiar de columna requiere clic o teclado; hover no desplaza la vista.
        sensitivity = 0, -- -1.0 - 1.0, 0 significa sin modificación

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Gesto de 3 dedos para cambiar de workspace
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Scratchpad desde el touchpad, sin interferir con el gesto de espacios.
hl.gesture({ fingers = 4, direction = "down", mods = "SUPER", action = "special", workspace_name = "scratchpad" })
