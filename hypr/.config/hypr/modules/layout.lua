------------------
---   LAYOUT    ---
------------------
-- Ver https://wiki.hypr.land/Configuring/Dwindle-Layout y Master-Layout

hl.config({
    dwindle = {
        --preserve_split: se mantiene la división al cambiar de ventana
        preserve_split = true,
        smart_split = false,
    },

    master = {
        new_status = "master",
    },
})
-- Columnas que conservan su tamaño al abrir más ventanas.
hl.config({ scrolling = {
    column_width = 0.5,
    fullscreen_on_one_column = true,
    focus_fit_method = 1,
    follow_focus = true,
    direction = "right",
    wrap_focus = false,
    wrap_swapcol = false,
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
} })
