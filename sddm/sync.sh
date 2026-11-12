#!/usr/bin/env bash
# Refreshes the Isla login screen's wallpaper and colours after a wallpaper
# change. Writes only to the user-owned folder sddm/install.sh creates, which the
# theme reads through theme.conf.user; no sudo. A no-op when it is missing.
set -euo pipefail

live="${ISLA_SDDM_LIVE:-/var/lib/isla-sddm}"
[[ -d $live && -w $live ]] || exit 0
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/matugen"
wall="$(readlink -f -- "$cache/current-wallpaper" 2>/dev/null || true)"

tmp="$(mktemp -d "$live/.sync.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
python3 "$here/theme-colors.py" "$cache/palette.json" "$tmp" live/ "$wall" > "$tmp/theme.conf.user"
chmod 644 "$tmp"/*

# Image first, then the conf that names it, so the greeter never reads a
# name whose file is missing; then drop images of other types.
new="$(cd "$tmp" && ls background.* 2>/dev/null || true)"
[[ -n $new ]] && mv -f -- "$tmp/$new" "$live/$new"
mv -f -- "$tmp/theme.conf.user" "$live/theme.conf.user"
for f in "$live"/background.*; do
    [[ -e $f && ${f##*/} != "$new" ]] && rm -f -- "$f"
done
exit 0
