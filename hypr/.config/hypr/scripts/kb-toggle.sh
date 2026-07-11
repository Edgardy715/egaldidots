#!/usr/bin/env bash
# Toggle keyboard layout between English (us) and Spanish (es), Windows-style.
# Triggered by:  bind = $mainMod, space, exec, ...
#
# Logic: read the main keyboard's active_layout_index (0=us, 1=es in "us,es"),
# switch to the other and apply it to ALL keyboards (keeps them in sync, even
# RGB peripherals that show up as "keyboards"), then notify which is active.

set -uo pipefail

DEV="$(hyprctl -j devices)"

# Main keyboard = the one actually used for typing.
MAIN="$(printf '%s' "$DEV" | jq -r '.keyboards[] | select(.main) | .name' | head -1)"
[ -z "$MAIN" ] && MAIN="$(printf '%s' "$DEV" | jq -r '.keyboards[0].name')"

# Active index in the "us,es" list  (0 = English, 1 = Spanish).
CUR="$(printf '%s' "$DEV" | jq -r --arg k "$MAIN" '.keyboards[] | select(.name==$k) | .active_layout_index')"
case "$CUR" in
    0) NEXT=1 ;;   # English -> Spanish
    *) NEXT=0 ;;   # Spanish -> English  (or any unexpected value)
esac

# Apply the same index to all keyboards to keep them in sync.
while read -r kb; do
    [ -n "$kb" ] && hyprctl switchxkblayout "$kb" "$NEXT" >/dev/null 2>&1 || true
done < <(printf '%s' "$DEV" | jq -r '.keyboards[].name')

sleep 0.06

# Read the resulting keymap of the main keyboard and notify.
LABEL="$(hyprctl -j devices | jq -r --arg k "$MAIN" '.keyboards[] | select(.name==$k) | .active_keymap')"
case "$LABEL" in
    *Spanish*) NAME="Spanish (ES)" ;;
    *)         NAME="English (US)"  ;;
esac

# -e  => transient (doesn't pile up in the notification center)
# -t  => 1.5 s;  -u low => low priority;  -i => icon from the icon theme
notify-send -e -t 1500 -u low -a "Keyboard" -i "input-keyboard" "$NAME"
