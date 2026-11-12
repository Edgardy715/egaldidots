#!/usr/bin/env bash
set -euo pipefail

for tool in slurp grim satty wl-copy; do
  command -v "$tool" >/dev/null || { printf 'Missing screenshot tool: %s\n' "$tool" >&2; exit 127; }
done

geometry=$(slurp -d) || exit 0
[[ -n $geometry ]] || exit 0

shots="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$shots"
grim -g "$geometry" - | satty --filename - --copy-command wl-copy \
  --output-filename "$shots/isla-%Y%m%d-%H%M%S.png" \
  --actions-on-enter save-to-clipboard
