#!/usr/bin/env python3
"""
wall-colors.py · Index ~/Wallpapers by dominant color and emit them sorted
by spectrum (red→violeta→mono) for `rofi -dmenu`.

Each line (canonical rofi row format: one \0 after the entry, options chained by \x1f):
  NAME  ·  BUCKET \0display\x1f <span color>●</span>   NAME \x1ficon\x1f ~/.cache/wall-picker/thumbs/<file>.png
  · visible : ● (dominant-color dot) + clean NAME via `display` → no clutter
  · filterable: type "blue", "red", "pink"… (the bucket lives in the content)
  · -select NAME highlights the current wallpaper (content starts with the name)

The dot keeps the wallpaper's hue, but `dot_color()` raises value/sat so it
reads on dark themes (the 1×1 dominant pixel often lands in a dark area).
Needs `rofi -markup-rows` so pango renders the <span>, else the caller
sees the markup literally.

rofi returns the *content* → the caller keeps only the name:
    SELECTED="${SELECTED%%  ·  *}"

mtime-keyed cache at ~/.cache/wall-picker/index.json → only re-extracts new/
changed wallpapers. On first run it extracts the dominant color with `magick`
(same 1×1 trick as ilyamiro, but a more honest threshold for near-blacks/
grays → "mono" instead of false reds).

Relies on pywal for the picker theme's colors; this script only classifies
the wallpapers themselves.
"""
import os, sys, subprocess, json, concurrent.futures

WALL_DIR = os.path.expanduser("~/Wallpapers")
CACHE_DIR = os.path.expanduser("~/.cache/wall-picker")
CACHE = os.path.join(CACHE_DIR, "index.json")
EXTS = (".jpg", ".jpeg", ".png", ".webp")
SEP = "  ·  "                       # separator ONLY in content (display hides it)
SPECTRUM = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "mono"]
FALLBACK = "#888888"
# Thumbnails: rofi scales megapixels poorly (5443×3061 / 15 MB → slow load or
# fails to show). Generate 480×270 thumbs and point the \0icon at them.
THUMB_DIR = os.path.join(CACHE_DIR, "thumbs")
THUMB_BOX = "480x270"


def magick_dominant(path):
    """Dominant color (hex #RRGGBB) via magick 1×1, or None on failure."""
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
    """HSV (h in degrees, s/v in 0..1) → #RRGGBB."""
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
    """Dot color: keep the wallpaper's hue but raise value/saturation so it's
    always visible on dark themes (the 1×1 dominant pixel often lands in a
    dark area and would give an invisible dot)."""
    try:
        hh, s, v = hex_to_hsv(hex_)
    except Exception:
        return FALLBACK
    if v < 0.10 or s < 0.15:        # near-blacks and grays → gray (unstable hue)
        return FALLBACK
    return hsv_to_hex(hh, max(s, 0.45), max(v, 0.62))


def bucket_of(hh, s, v):
    if v < 0.10 or s < 0.15:        # desaturated near-blacks and grays → mono (more honest)
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
    """Return the 480×270 thumbnail (transparent letterbox) of `path`, cached in
    ~/.cache/wall-picker/thumbs/<name>.png and regenerated only when the
    wallpaper's mtime changes. If it can't be generated, return `path` (rofi
    will fall back to the original)."""
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
                 "-resize", THUMB_BOX + ">",        # only shrink, don't enlarge
                 "-background", "none",
                 "-gravity", "center",
                 "-extent", THUMB_BOX,              # exact 16:9 canvas, transparent margins
                 "-strip", "-define", "png:compression-level=6", thumb],
                capture_output=True, timeout=20)
            try:
                os.utime(thumb, (mtime, mtime))     # sync mtime for the cache key
            except OSError:
                pass
        except Exception:
            pass
    return thumb if os.path.isfile(thumb) else path


def compute(path, name, live_names):
    """Return the cached or freshly-extracted {hex,bucket,...} dict."""
    try:
        mtime = int(os.path.getmtime(path))
    except OSError:
        return {"hex": FALLBACK, "bucket": "mono", "mtime": 0}

    c = load_cache()
    e = c["entries"].get(name)
    if e and e.get("mtime") == mtime:
        # reuse; but also purge deleted entries from the cache
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
    # purge ones that no longer exist
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

    # Pre-generate thumbnails in parallel (cold cache: ~13s → ~2s).
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
        # Canonical rofi row-options format: ONE \0 after the entry, key\x1fvalue
        # pairs chained by \x1f. An extra \0 makes the parser swallow `icon` into
        # `display` and the thumb never loads.
        out.write(f"{line}\0display\x1f{disp}\x1ficon\x1f{thumb}\n")
    out.flush()


if __name__ == "__main__":
    main()
