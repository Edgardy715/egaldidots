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

FULL_PATH=$(find "$WALLPAPER_DIR" -type f \( -name "$NAME.jpg" -o -name "$NAME.jpeg" -o -name "$NAME.png" -o -name "$NAME.webp" \) | head -1)

[ -z "$FULL_PATH" ] && exit 0

awww img "$FULL_PATH" \
  --transition-type grow \
  --transition-pos center \
  --transition-duration 1.2 \
  --transition-bezier 0.1,1,0,1 \
  --transition-fps 144

(
  wal -i "$FULL_PATH" -n -q -b "#1e1e2e"
  wpg -s "$FULL_PATH"
  ln -sf "$FULL_PATH" ~/.cache/wal/current-wallpaper
  python3 ~/.config/hypr/scripts/generate-rofi-theme.py
  pkill -USR1 nvim 2>/dev/null

  fish -c "set -U wal_sync_signal (date +%s)"
) &

sleep 1.2
wait

killall waybar
sleep 0.5
hyprctl reload &>/dev/null
waybar &>/dev/null &
disown
swaync-client -rs &>/dev/null
