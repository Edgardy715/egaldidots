#!/usr/bin/env python3
"""Prints theme.conf colour and background lines from Matugen's palette.

usage: theme-colors.py PALETTE OUTDIR PREFIX [WALLPAPER]

Copies the wallpaper (WALLPAPER, or the palette's own) into OUTDIR as
background.<ext> and writes background=PREFIX + that name. Only #rrggbb
colours and known image types pass through.
"""
import json, os, re, shutil, sys

palette, out, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
hexre = re.compile(r"^#[0-9a-fA-F]{6}$")
try:
    data = json.load(open(palette))
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
colors = data.get("colors", {})
if not isinstance(colors, dict):
    colors = {}
keys = {"bgColor": "background", "foreground": "on_surface", "secondary": "on_surface_variant",
        "accent": "primary", "error": "error", "cardTop": "surface_container_high",
        "cardBot": "surface_container_low", "outline": "outline_variant"}
print("[General]")
for k, v in keys.items():
    c = colors.get(v)
    if isinstance(c, str) and hexre.match(c):
        print(f"{k}={c}")
wall = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else data.get("wallpaper")
if isinstance(wall, str) and os.path.isfile(wall):
    ext = os.path.splitext(wall)[1].lower()
    if ext in (".png", ".jpg", ".jpeg", ".webp"):
        shutil.copyfile(wall, os.path.join(out, "background" + ext))
        print("background=" + prefix + "background" + ext)
