#!/usr/bin/env python3
"""
lock-mpris.py · "now playing" en UNA línea de TEXTO PLANO para hyprlock.

  lock-mpris.py line   →  "󰈹  Artista — Título"   (solo si está sonando)
                          ""                          (pausado / sin player)

Por qué texto plano: hyprlock escapa la salida de `cmd` antes de renderizar,
así que el markup Pango (<span>) saldría literal en pantalla.  El color lo
aporta el label del .conf ($accent), no el script.

Por qué una línea sin caja: hyprlock NO recorta el texto al shape → si el
título es más ancho que la píldora, se desborda.  Una línea tipográfica
flotante (como el reloj y la fecha, que tampoco tienen caja) evita eso y es
más minimalista.  Solo visible mientras reproduce (hide-on-pause, igual que
el módulo mpris de waybar); al pausar o parar la línea desaparece sin dejar
rastro.

Lectura con una sola llamada `playerctl --format` (rápido).  Tolerante: sin
player / pausado / sin título / playerctl ausente → nunca rompe, devuelve "".
"""
import sys, subprocess

PLAYER  = "playerctl"
TIMEOUT = 1.4

PLAYER_ICONS = {
    "spotify":  "󰓇", "firefox":   "󰈹", "chromium":  "",
    "mpv":      "󰝚", "vlc":       "󰕼", "music":     "󰝚",
    "youtube":  "󰗃", "default":   "󰝚",
}
MAXLEN = 40


def sh(*args):
    """playerctl callado; '' si no hay player o falla."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=TIMEOUT)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def trunc(s, n):
    s = (s or "").strip()
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def line():
    """ 󰈹  Artista — Título  si está sonando;  ''  si no."""
    if sh(PLAYER, "status") != "Playing":
        return ""                            # pausado/parado/idle → invisible
    meta = sh(PLAYER, "metadata", "--format",
              "{{playerName}}|{{title}}|{{artist}}")
    if not meta or "|" not in meta:
        return ""
    parts = meta.split("|")
    if len(parts) < 3:
        return ""
    player = parts[0].strip()
    artist = parts[-1].strip()
    title  = "|".join(parts[1:-1]).strip()  # tolera '|' dentro del título
    if not title:
        return ""
    name = f"{artist} — {title}" if artist else title
    icon = PLAYER_ICONS.get((player or "").lower(), PLAYER_ICONS["default"])
    return f"{icon}  {trunc(name, MAXLEN)}"


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "line"
    if mode == "debug":
        print(repr(line()))
    else:
        print(line())
