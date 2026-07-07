#!/usr/bin/env python3
"""
wall-colors.py · Indexa los wallpapers de ~/Wallpapers por color dominante
y los emite, ordenados por espectro (rojo→violeta→mono), listos para
`rofi -dmenu`.

Cada línea es (formato canónico de rofi: un \0 tras la entrada, opciones encadenadas con \x1f):
  NOMBRE  ·  BUCKET \0display\x1f <span color>●</span>   NOMBRE \x1ficon\x1f ~/.cache/wall-picker/thumbs/<archivo>.png
  · visible  : ● (punto del color dominante) + NOMBRE limpio, vía `display` → sin ruido
  · filtable : escribe "blue", "red", "pink"…  (el bucket vive en el content)
  · -select NOMBRE resalta el wallpaper actual (el content arranca con el nombre)

El punto conserva el *matiz* del wallpaper pero `dot_color()` sube value/sat
para que se vea sobre tema oscuro (el píxel dominante 1×1 suele caer en
zonas oscuras). Requiere `rofi -markup-rows` para que pango renderice el
<span>; de lo contrario el caller vería el markup literal.

rofi devuelve el *content* → el caller debe quedarse con el nombre:
    SELECTED="${SELECTED%%  ·  *}"

Caché mtime-keyed en ~/.cache/wall-picker/index.json → solo re-extrae lo
nuevo/cambiado. En el primer arranque de cada wallpaper extrae su color
dominante con `magick` (mismo truco 1×1 que usa ilyamiro, pero con un umbral
más honesto para casi-negros/grises → "mono" en vez de falsos rojos).

Nos apoyamos en pywal para los colores del tema del picker; este script
solo clasifica los wallpapers en sí.
"""
import os, sys, subprocess, json, concurrent.futures

WALL_DIR = os.path.expanduser("~/Wallpapers")
CACHE_DIR = os.path.expanduser("~/.cache/wall-picker")
CACHE = os.path.join(CACHE_DIR, "index.json")
EXTS = (".jpg", ".jpeg", ".png", ".webp")
SEP = "  ·  "                       # separador SOLO en content (display lo oculta)
SPECTRUM = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "mono"]
FALLBACK = "#888888"
# Miniaturas: rofi no escala bien megapíxeles (5443×3061 / 15 MB → carga lenta o
# falla y no muestra nada). Generamos thumbs 480×270 y apuntamos el \0icon a ellas.
THUMB_DIR = os.path.join(CACHE_DIR, "thumbs")
THUMB_BOX = "480x270"


def magick_dominant(path):
    """Color dominante (hex #RRGGBB) via magick 1×1, o None si falla."""
    try:
        out = subprocess.run(
            ["magick", path, "-resize", "1x1^", "-gravity", "center",
             "-extent", "1x1", "-depth", "8", "-format", "%[hex:p{0,0}]", "info:-"],
            capture_output=True, text=True, timeout=15)
        h = out.stdout.strip()
        if len(h) in (6, 8):
            return "#" + h[:6].upper()
    except Exception:
        pass
    return None


def hex_to_hsv(h):
    h = h.lstrip("#")
    r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    v = mx
    s = (d / mx) if mx > 0 else 0.0
    if d == 0:
        hh = 0
    elif mx == r:
        hh = ((g - b) / d) % 6
    elif mx == g:
        hh = (b - r) / d + 2
    else:
        hh = (r - g) / d + 4
    return hh * 60.0, s, v


def hsv_to_hex(hh, s, v):
    """HSV (h en grados, s/v en 0..1) → #RRGGBB."""
    c = v * s
    x = c * (1 - abs((hh / 60.0) % 2 - 1))
    m = v - c
    if hh < 60:     r, g, b = c, x, 0
    elif hh < 120:  r, g, b = x, c, 0
    elif hh < 180:  r, g, b = 0, c, x
    elif hh < 240:  r, g, b = 0, x, c
    elif hh < 300:  r, g, b = x, 0, c
    else:           r, g, b = c, 0, x
    return "#{:02X}{:02X}{:02X}".format(
        round((r + m) * 255), round((g + m) * 255), round((b + m) * 255))


def dot_color(hex_):
    """Color del punto: conserva el matiz del wallpaper pero sube value/sat
    para que siempre se vea sobre tema oscuro (el píxel dominante 1×1
    suele caer en zonas oscuras y daría un punto invisible)."""
    try:
        hh, s, v = hex_to_hsv(hex_)
    except Exception:
        return FALLBACK
    if v < 0.10 or s < 0.15:        # casi-negros y grises → gris (matiz inestable)
        return FALLBACK
    return hsv_to_hex(hh, max(s, 0.45), max(v, 0.62))


def bucket_of(hh, s, v):
    if v < 0.10 or s < 0.15:        # casi-negros y grises desaturados → mono (más honesto)
        return "mono"
    if hh >= 345 or hh < 15:
        return "red"
    if hh < 45:
        return "orange"
    if hh < 75:
        return "yellow"
    if hh < 165:
        return "green"
    if hh < 260:
        return "blue"
    if hh < 315:
        return "purple"
    return "pink"


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except Exception:
        return {"v": 1, "entries": {}}


def save_cache(c):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE, "w") as f:
            json.dump(c, f, indent=2)
    except Exception:
        pass


def ensure_thumb(path, name):
    """Devuelve la miniatura 480×270 (letterbox transparente) de `path`,
    cacheada en ~/.cache/wall-picker/thumbs/<name>.png y regenerada solo si
    el mtime del wallpaper cambia. Si no puede generarla, devuelve `path`
    (rofi aún intentará la original como fallback)."""
    os.makedirs(THUMB_DIR, exist_ok=True)
    thumb = os.path.join(THUMB_DIR, os.path.splitext(name)[0] + ".png")
    try:
        mtime = int(os.path.getmtime(path))
    except OSError:
        return path
    fresh = os.path.isfile(thumb)
    try:
        stale = fresh and int(os.path.getmtime(thumb)) != mtime
    except OSError:
        stale = True
    if not fresh or stale:
        try:
            subprocess.run(
                ["magick", path,
                 "-resize", THUMB_BOX + ">",        # solo encoge, no amplía
                 "-background", "none",
                 "-gravity", "center",
                 "-extent", THUMB_BOX,              # canvas exacto 16:9, márgenes transparentes
                 "-strip", "-define", "png:compression-level=6", thumb],
                capture_output=True, timeout=20)
            try:
                os.utime(thumb, (mtime, mtime))     # sincroniza mtime para la key caché
            except OSError:
                pass
        except Exception:
            pass
    return thumb if os.path.isfile(thumb) else path


def compute(path, name, live_names):
    """Devuelve el dict {hex,bucket,...} cacheado o recién extraído."""
    try:
        mtime = int(os.path.getmtime(path))
    except OSError:
        return {"hex": FALLBACK, "bucket": "mono", "mtime": 0}

    c = load_cache()
    e = c["entries"].get(name)
    if e and e.get("mtime") == mtime:
        # reutiliza; pero aprovecha para purgar los borrados de la caché
        if set(c["entries"].keys()) - live_names:
            for k in list(c["entries"]):
                if k not in live_names:
                    del c["entries"][k]
            save_cache(c)
        return e

    hex_ = magick_dominant(path) or FALLBACK
    hh, s, v = hex_to_hsv(hex_)
    e = {"hex": hex_, "bucket": bucket_of(hh, s, v),
         "mtime": mtime, "hue": round(hh, 1), "sat": round(s, 3), "val": round(v, 3)}
    c["entries"][name] = e
    # purga los que ya no existen
    for k in list(c["entries"]):
        if k not in live_names:
            del c["entries"][k]
    save_cache(c)
    return e


def main():
    if not os.path.isdir(WALL_DIR):
        return

    names = sorted(f for f in os.listdir(WALL_DIR)
                   if f.lower().endswith(EXTS) and os.path.isfile(os.path.join(WALL_DIR, f)))
    live = set(names)

    rows = []
    for n in names:
        e = compute(os.path.join(WALL_DIR, n), n, live)
        idx = SPECTRUM.index(e["bucket"]) if e["bucket"] in SPECTRUM else len(SPECTRUM)
        rows.append((idx, n, e))

    rows.sort(key=lambda r: (r[0], r[1].lower()))

    # Pre-genera las miniaturas en paralelo (caché fría: ~13 s → ~2 s).
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        thumbs = dict(zip(names, ex.map(
            lambda n: ensure_thumb(os.path.join(WALL_DIR, n), n), names)))

    out = sys.stdout
    for _idx, n, e in rows:
        clean = os.path.splitext(n)[0]
        dot = dot_color(e["hex"])
        thumb = thumbs[n]
        line = f"{clean}{SEP}{e['bucket']}"
        disp = f'<span foreground="{dot}">●</span>   {clean}'
        # Formato canónico de rofi para varias opciones de fila: UN \0 tras la
        # entrada, pares key\x1fvalue encadenados por \x1f.  Con \0 extra el
        # parser se traga `icon` dentro de `display` y el thumb no carga nunca.
        out.write(f"{line}\0display\x1f{disp}\x1ficon\x1f{thumb}\n")
    out.flush()


if __name__ == "__main__":
    main()
