#!/usr/bin/env bash
set -euo pipefail

for tool in slurp grim satty wl-copy; do
  command -v "$tool" >/dev/null || { printf 'Missing screenshot tool: %s\n' "$tool" >&2; exit 127; }
done

geometry=$(slurp -d) || exit 0
[[ -n $geometry ]] || exit 0

shots="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$shots"
output="$shots/isla-$(date +%Y%m%d-%H%M%S-%N).png"
grim -g "$geometry" - | satty --filename - --copy-command wl-copy \
  --output-filename "$output" \
  --actions-on-enter save-to-clipboard

# Offer only a file actually saved by the editor; clipboard-only remains unchanged.
if [[ -f $output ]] && command -v qs >/dev/null; then
  qs ipc -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/bar/shell.qml" \
    call island bodyFile "$output" >/dev/null 2>&1 || true
fi
