#!/usr/bin/env python3

import os

colors = {}
with open(os.path.expanduser('~/.cache/wal/colors.sh')) as f:
    for line in f:
        line = line.strip()
        if line.startswith('color') or line.startswith('background') or line.startswith('foreground'):
            if '=' in line:
                k, v = line.split('=', 1)
                colors[k.strip()] = v.strip().strip("'")


# Forzar foreground siempre legible
colors['foreground'] = '#cdd6f4'
# Forzar color8 con suficiente contraste
r, g, b = tuple(int(colors.get('color8', '#5e5e74').lstrip('#')[i:i+2], 16) for i in (0, 2, 4))
brightness = (r * 299 + g * 587 + b * 114) / 1000
if brightness > 128:
    colors['color8'] = '#45475a'


# Wallpaper actual (para el caption del picker) — leído del cache de pywal
cur_name = ''
wp_file = os.path.expanduser('~/.cache/wal/wal')
if os.path.exists(wp_file):
    with open(wp_file) as fh:
        wp = fh.read().strip()
    if wp:
        cur_name = os.path.basename(wp).rsplit('.', 1)[0]
caption = f"actual: {cur_name}   ·   buscar..." if cur_name else "󰋩  buscar wallpaper..."


# Helper: hex (#1e1e2e) -> rofi rgba(r, g, b, alpha)
def rgba(hex_color, alpha):
    h = hex_color.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r:d}, {g:d}, {b:d}, {alpha:.2f})"


# Paleta glass derivada de pywal (siempre en sync con el wallpaper actual)
bg      = colors.get('background', '#1e1e2e')
fg      = colors.get('foreground', '#cdd6f4')
accent  = colors.get('color4', colors.get('color2', '#89b4fa'))
dim     = colors.get('color8', '#45475a')

theme = f"""configuration {{
    font: "JetBrains Mono Nerd Font 12";
    show-icons: true;
    hover-select: true;
    me-select-entry: "MouseSecondary";
    me-accept-entry: "MousePrimary";
}}
* {{
    text-color: {fg};
    background-color: transparent;
    border-color: {rgba(fg, 0.10)};
}}
/* ── Panel de cristal (blur via Hyprland layerrule) ── */
window {{
    transparency: "real";
    fullscreen: false;
    cursor: "default";
    border-radius: 16px;
    location: center;
    anchor: center;
    width: 75%;
    background-color: {rgba(bg, 0.62)};
    border: 1px solid;
    border-color: {rgba(fg, 0.10)};
}}
mainbox {{
    children: [ "inputbar", "listview", "message" ];
    background-color: transparent;
    padding: 14px;
    spacing: 14px;
}}
/* ── Píldora de búsqueda (isla) ── */
inputbar {{
    text-color: {rgba(fg, 0.85)};
    background-color: {rgba(bg, 0.45)};
    border: 1px solid;
    border-color: {rgba(fg, 0.08)};
    border-radius: 99px;
    padding: 8px 16px;
    margin: 0 6px;
    spacing: 8px;
    children: [ "prompt", "entry" ];
}}
/* icono de busqueda pintado en el acento de pywal */
prompt {{
    text-color: {rgba(accent, 0.95)};
    background-color: transparent;
    padding: 0 6px 0 2px;
}}
entry {{
    text-color: inherit;
    background-color: transparent;
    placeholder: "{caption}";
    placeholder-color: {rgba(fg, 0.40)};
}}
/* ── Galería de thumbnails ── */
listview {{
    columns: 5;
    lines: 2;
    padding: 0 6px 6px 6px;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    layout: horizontal;
    fixed-height: true;
    fixed-columns: true;
    background-color: transparent;
    spacing: 18px;
    border: 0px;
}}
element {{
    orientation: vertical;
    expand: false;
    spacing: 8px;
    padding: 8px;
    border-radius: 12px;
    cursor: pointer;
    background-color: transparent;
    border: 1px solid;
    border-color: transparent;
}}
element normal.normal {{
    background-color: transparent;
    text-color: {rgba(fg, 0.65)};
}}
/* Thumbnail seleccionado: se "enciende" con el acento */
element selected.normal {{
    background-color: {rgba(accent, 0.22)};
    text-color: {fg};
    border: 1px solid;
    border-color: {rgba(accent, 0.70)};
    border-radius: 12px;
}}
element alternate.normal {{
    background-color: transparent;
    text-color: {rgba(fg, 0.50)};
}}
element-icon {{
    size: 50%;
    cursor: inherit;
    expand: false;
    padding: 0px;
    background-color: transparent;
    border-radius: 10px;
    border: 1px solid;
    border-color: {rgba(fg, 0.06)};
}}
element-text {{
    cursor: inherit;
    background-color: transparent;
    text-color: inherit;
    font: "JetBrains Mono Nerd Font 9";
    horizontal-align: 0.5;
}}
/* ── Footer de atajos (tenue; contenido via -mesg del script) ── */
message {{
    background-color: transparent;
    margin: 6px 0 2px 0;
    padding: 0;
}}
message textbox {{
    background-color: transparent;
    text-color: {rgba(fg, 0.30)};
    font: "JetBrains Mono Nerd Font 9";
    padding: 4px;
    horizontal-align: 0.5;
    str: "↑↓  Navegar    ⏎  Aplicar    Esc  Cerrar";
}}
"""

output = os.path.expanduser('~/.config/rofi/themes/wallpaper-picker.rasi')
with open(output, 'w') as f:
    f.write(theme)

# ──────────────────────────────────────────────────────────────────
# hyprlock · paleta glass en hyprlang (mismos colores y fg-forzado que rofi)
# Se consume con `source = ~/.cache/wal/colors-hyprlock.conf` en hyprlock.conf.
# Regenerado automáticamente en cada cambio de theme (wal -i / wallpaper-picker),
# igual que el tema rofi — el lock screen sigue el mismo wallpaper que el resto.
# ──────────────────────────────────────────────────────────────────
hypr = f"""# Generado por generate-rofi-theme.py desde el wallpaper actual — NO EDITAR.
# Se regenera en cada cambio de theme (wal -i / wallpaper-picker).

$bg           = {rgba(bg, 1.0)}
$fg           = {rgba(fg, 1.0)}
$muted        = {rgba(fg, 0.55)}
$faint        = {rgba(fg, 0.32)}
$accent       = {rgba(accent, 1.0)}
$accent_soft  = {rgba(accent, 0.60)}
$accent_glow  = {rgba(accent, 0.28)}
$hair         = {rgba(fg, 0.10)}
$glass        = {rgba(bg, 0.42)}
$glass_strong = {rgba(bg, 0.62)}
"""
with open(os.path.expanduser('~/.cache/wal/colors-hyprlock.conf'), 'w') as f:
    f.write(hypr)

print("Theme generated successfully")

