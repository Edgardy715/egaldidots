local palette = require("modules.palette")

-- HyprGlass se limita a Kitty; Isla conserva su material y sus contornos.
-- El plugin se carga fuera de la evaluación de la config (en 0.57 se ignora aquí):
-- el loader lo registra tras el arranque y recarga una vez para aplicar este módulo.
hl.on("hyprland.start", function()
    hl.exec_cmd(require("modules.isla").script("hyprglass-load.sh"))
end)

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    hg.config({
        enabled = false,
        default_theme = "dark",
        default_preset = "isla-matte",
        layers = { enabled = false },
        subsurfaces = { enabled = false },
    })
    -- Vidrio esmerilado: grano fino, bisel con luz arriba-izquierda y luz de foco
    -- con el acento Matugen. Un solo blur (el de hyprglass) para no duplicar coste.
    local accent = palette.color("isla_primary", "rgba(bcc2ffff)")
    hg.preset("isla-matte", {
        inherits = "subtle",
        glass_opacity = 0.9,
        blur_strength = 0.9,
        blur_iterations = 2,
        noise_strength = 0.10,
        brightness = 0.85,
        contrast = 1.1,
        vibrancy = 0.35,
        refraction_strength = 0.25,
        refraction_spread = 0.20,
        chromatic_aberration = 0.04,
        lens_distortion = 0.0,
        specular_strength = 0.35,
        fresnel_strength = 0.30,
        bevel_strength = 0.30,
        bevel_size = 3,
        bevel_tint = 0.3,
        focus_light = 0.45,
        focus_light_color = palette.as_int(accent, 200),
        self_sample = 0.0,
    })
    hl.window_rule({ name = "kitty-glass", match = { class = "^(kitty)$" }, tag = "+hyprglass_enabled" })
    hl.window_rule({ name = "fullscreen-no-glass", match = { fullscreen = true }, tag = "+hyprglass_disabled" })
end
