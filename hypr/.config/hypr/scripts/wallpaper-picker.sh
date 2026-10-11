#!/bin/bash

WALLPAPER_DIR="$HOME/Wallpapers"
CURRENT_WALL=$(cat ~/.cache/wal/wal 2>/dev/null)
CURRENT_NAME=$(basename "$CURRENT_WALL" 2>/dev/null | sed 's/\.[^.]*$//')

SELECTED=$(python3 ~/.config/hypr/scripts/wall-colors.py |
  rofi -dmenu \
    -i \
    -markup-rows \
    -p "󰋩" \
    -mesg "↑↓  Navigate    ⏎  Apply    type «red/blue/pink…» to filter by color    Esc  Close" \
    -show-icons \
    -icon-theme "" \
    -theme ~/.config/rofi/themes/wallpaper-picker.rasi \
    -select "$CURRENT_NAME")

[ -z "$SELECTED" ] && exit 0

# wall-colors.py emits content as "NAME  ·  BUCKET" → drop the bucket
NAME="${SELECTED%%  ·  *}"

[ -z "$NAME" ] && exit 0

FULL_PATH=$(find -L "$WALLPAPER_DIR" -type f \( -name "$NAME.jpg" -o -name "$NAME.jpeg" -o -name "$NAME.png" -o -name "$NAME.webp" \) | head -1)

[ -z "$FULL_PATH" ] && exit 0

exec bash "$HOME/.config/hypr/scripts/apply-wallpaper.sh" "$FULL_PATH"
