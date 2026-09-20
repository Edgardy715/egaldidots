#!/usr/bin/env python3
"""
lock-mpris.py · single-line PLAIN-TEXT "now playing" for hyprlock.

  lock-mpris.py line   →  "󰈹  Artist — Title"   (only while playing)
                          ""                       (paused / no player)

Why plain text: hyprlock escapes `cmd` output before rendering, so Pango
markup (<span>) would show up literally. Color comes from the .conf label
($accent), not the script.

Why a boxless line: hyprlock doesn't clip text to shapes → a title wider
than a pill would overflow. A floating typographic line (like the clock and
date, also boxless) avoids that and is more minimal. Shown only while playing
(hide-on-pause, like waybar's mpris); on pause/stop the line disappears.

One `playerctl --format` call (fast). Tolerant: no player / paused / no
title / playerctl missing → never throws, returns "".
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
    """playerctl, quiet; '' if no player or it fails."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=TIMEOUT)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def trunc(s, n):
    s = (s or "").strip()
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def line():
    """ 󰈹  Artist — Title  if playing;  ''  otherwise."""
    if sh(PLAYER, "status") != "Playing":
        return ""                            # paused/stopped/idle → invisible
    meta = sh(PLAYER, "metadata", "--format",
              "{{playerName}}|{{title}}|{{artist}}")
    if not meta or "|" not in meta:
        return ""
    parts = meta.split("|")
    if len(parts) < 3:
        return ""
    player = parts[0].strip()
    artist = parts[-1].strip()
    title  = "|".join(parts[1:-1]).strip()  # tolerate '|' inside the title
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
