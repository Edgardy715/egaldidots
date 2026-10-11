#!/usr/bin/env bash
# Shared by Isla, the legacy picker and first-install palette generation.
set -Eeuo pipefail
seed=0
if [[ "${1:-}" == --seed ]]; then seed=1; shift; fi
[[ $# == 1 && -f "$1" ]] || { echo 'Usage: apply-wallpaper.sh [--seed] IMAGE' >&2; exit 1; }
wall="$(realpath -- "$1")"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/.cache/wal"
exec 9>"$HOME/.cache/wal/isla-apply.lock"
flock 9
changed=0
failed() {
    echo 'Wallpaper palette/GTK generation failed.' >&2
    if (( changed )); then exit 3; else exit 1; fi
}
trap failed ERR
if (( ! seed )); then
    awww img "$wall" --transition-type grow --transition-pos center --transition-duration 1.2
    changed=1
fi
wal -i "$wall" -n -s -e -q -b '#1e1e2e'
name="$(basename -- "$wall")"
name="${name// /_}"
listed="$(wpg -l)"
if ! printf '%s\n' "$listed" | rg -Fx -- "$name" >/dev/null; then wpg -a "$wall"; fi
# Use the exact pywal palette, rather than deriving a second GTK palette.
wpg -i "$name" "$HOME/.cache/wal/colors.json"
wpg -n --noterminal -s "$name"
ln -sfn -- "$wall" "$HOME/.cache/wal/current-wallpaper"
python3 "$script_dir/generate-rofi-theme.py"
python3 "$HOME/.config/starship/pywal.py"
fish --no-config -c 'set -U wal_sync_signal (date +%s%N)'
if (( ! seed )); then
    # Optional live clients may be absent; generation above is mandatory.
    hyprctl reload >/dev/null 2>&1 || true
    swaync-client -rs >/dev/null 2>&1 || true
    pkill -USR1 -x nvim >/dev/null 2>&1 || true
fi
