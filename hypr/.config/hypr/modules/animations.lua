-- Movimiento de ventanas y capas inspirado en serpantinum (d7aa27e).
-- Los efectos propios de borde y reflow se conservan.
hl.config({ animations = { enabled = true, workspace_wraparound = true } })

hl.curve("serpantinum", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("vidrio", { type = "bezier", points = { { 0.25, 1 }, { 0.25, 1 } } })
hl.curve("softFluid", { type = "bezier", points = { { 0.2, 1 }, { 0.2, 1 } } })
hl.curve("springSmooth", { type = "spring", mass = 1, stiffness = 620, dampening = 43 })

-- La nueva columna entra como una lámina, sin cambiar la escala del contenido.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.6, bezier = "softFluid", style = "slide right" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "serpantinum", style = "popin 97%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.4, spring = "springSmooth" })

hl.animation({ leaf = "layersIn", enabled = true, speed = 2.2, bezier = "serpantinum", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "serpantinum", style = "fade" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "serpantinum" })
-- Separar workspaces de las columnas scrolling evita arrastrar ventanas fuera de vista.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "serpantinum", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.6, bezier = "serpantinum", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.8, bezier = "serpantinum", style = "fade" })

hl.animation({ leaf = "border", enabled = true, speed = 2.2, bezier = "vidrio" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 2.4, bezier = "standard", style = "once" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 2.4, bezier = "standard", style = "once" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 2.6, bezier = "softFluid" })

-- El foco cambia con luz y profundidad, sin rebote en el brillo.
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 1.8, bezier = "standard" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 2.2, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.8, bezier = "standard" })
