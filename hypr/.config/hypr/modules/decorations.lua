-------------------------
--- DECORATIONS / LOOK ---
-------------------------
-- Aspecto visual. Lee los colores de Matugen directamente desde
-- ~/.cache/matugen/outputs/colors-hyprland.conf (equivalente Lua del `source` de hyprlang).

local palette = require("modules.palette")

-- Colores usados en los bordes (se leen al cargar; si el archivo aún no existe
-- se usan los últimos valores conocidos de la paleta).
local color4 = palette.color("isla_primary", "rgba(b0afb1ff)")
local color2 = palette.color("isla_secondary", "rgba(949395ff)")
local color8 = palette.color("isla_outline", "rgba(695555ff)")

local lower_alpha = palette.with_alpha

hl.config({
    general = {
        gaps_in = 7.5,
        gaps_out = 15,
        border_size = 1,
        col = {
            -- Gradiente activo (tabla moderna de Lua; `$color4 $color2 45deg` en hyprlang)
            active_border = { colors = { color4, color2 }, angle = 45 },
            inactive_border = color8,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "scrolling",
    },

    decoration = {
        rounding = 12,
        rounding_power = 4,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        -- Foco: atenúa apenas las ventanas inactivas para que el ojo nunca
        -- pierda la activa (con el fadeDim del sistema se siente orgánico).
        dim_inactive = true,
        dim_strength = 0.10,

        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "rgba(10101888)",
            color_inactive = "rgba(10101844)",
        },

        -- Glow interior: halo sutil con el color de acento Matugen en la ventana
        -- activa — el "borde vivo 2.0". Alpha bajo para que sea luz, no borde.
        glow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = lower_alpha(color4, "40"),
            color_inactive = "rgba(00000000)",
        },

        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            vibrancy = 0.25,
            noise = 0.012,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
            -- Popups Wayland (menús contextuales) con el mismo vidrio del sistema.
            popups = true,
            popups_ignorealpha = 0.2,
        },
    },
})