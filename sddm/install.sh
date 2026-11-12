#!/usr/bin/env bash
# Installs the Isla SDDM theme with the current Matugen palette, wallpaper and font.
# Run as your normal user; sudo is used only to copy into /usr/share and /etc.
#   sddm/install.sh              install or refresh (rerun after changing wallpaper)
#   sddm/install.sh --uninstall  restore the previous theme and remove Isla's
#   --root DIR                   install under DIR instead of / (tests; no sudo)
set -euo pipefail

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/isla"
root=/
mode=install
while (( $# )); do
    case "$1" in
        --uninstall) mode=uninstall ;;
        --root) root="${2:?--root needs a directory}"; shift ;;
        *) printf 'usage: %s [--uninstall] [--root DIR]\n' "$0" >&2; exit 2 ;;
    esac
    shift
done
die() { printf 'isla sddm: %s\n' "$*" >&2; exit 1; }
(( EUID != 0 )) || die "run as your normal user, not with sudo"

theme_dir="${root%/}/usr/share/sddm/themes/isla"
conf="${root%/}/etc/sddm.conf"
as_root=(sudo)
[[ "$root" != / ]] && as_root=()

# Rewrites [Theme] Current= in sddm.conf, keeping every other line as it was.
set_current() {
    python3 - "$1" "$2" <<'EOF'
import sys
path, theme = sys.argv[1], sys.argv[2]
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    lines = []
out, section, done = [], None, False
for line in lines:
    s = line.strip()
    if s.startswith("[") and s.endswith("]"):
        if section == "Theme" and not done:
            out.append("Current=" + theme); done = True
        section = s[1:-1]
    elif section == "Theme" and s.startswith("Current="):
        if not done:
            out.append("Current=" + theme); done = True
        continue
    out.append(line)
if not done:
    if section != "Theme":
        if out and out[-1].strip():
            out.append("")
        out.append("[Theme]")
    out.append("Current=" + theme)
sys.stdout.write("\n".join(out) + "\n")
EOF
}
current_theme() {
    [[ -r "$conf" ]] || return 0
    awk -F= '/^\[/{t=($0=="[Theme]")} t&&$1=="Current"{v=$2} END{print v}' "$conf"
}

stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

if [[ $mode == uninstall ]]; then
    [[ -d "$theme_dir" ]] || die "Isla theme is not installed"
    previous="$(cat "$theme_dir/previous-theme" 2>/dev/null || true)"
    [[ $previous =~ ^[A-Za-z0-9._-]+$ && $previous != isla ]] || previous=""
    if [[ "$(current_theme)" == isla ]]; then
        if [[ -n $previous ]]; then
            set_current "$conf" "$previous" > "$stage/sddm.conf"
            "${as_root[@]}" install -m644 "$stage/sddm.conf" "$conf"
        else
            # No recorded theme: drop Current= so SDDM uses its default.
            grep -v '^Current=isla$' "$conf" > "$stage/sddm.conf" || true
            "${as_root[@]}" install -m644 "$stage/sddm.conf" "$conf"
        fi
    fi
    "${as_root[@]}" rm -rf -- "$theme_dir"
    printf 'Isla SDDM theme removed; login theme: %s\n' "${previous:-SDDM default}"
    exit 0
fi

command -v python3 >/dev/null || die "python3 is required"
[[ -f "$src/Main.qml" ]] || die "theme source not found at $src"
mkdir "$stage/isla"
cp "$src/Main.qml" "$src/metadata.desktop" "$stage/isla/"

palette="${XDG_CACHE_HOME:-$HOME/.cache}/matugen/palette.json"
# Only colours, a locale and file names reach theme.conf; nothing from the user's
# home is read by the greeter itself.
python3 - "$palette" "$stage/isla" <<'EOF' > "$stage/isla/theme.conf"
import json, re, sys, shutil, os
palette, out = sys.argv[1], sys.argv[2]
hexre = re.compile(r"^#[0-9a-fA-F]{6}$")
try:
    data = json.load(open(palette))
except Exception:
    data = {}
colors = data.get("colors", {}) if isinstance(data, dict) else {}
keys = {"bgColor": "background", "foreground": "on_surface", "secondary": "on_surface_variant",
        "accent": "primary", "error": "error", "cardTop": "surface_container_high",
        "cardBot": "surface_container_low"}
print("[General]")
for k, v in keys.items():
    c = colors.get(v)
    if isinstance(c, str) and hexre.match(c):
        print(f"{k}={c}")
wall = data.get("wallpaper") if isinstance(data, dict) else None
if isinstance(wall, str) and os.path.isfile(wall):
    ext = os.path.splitext(wall)[1].lower()
    if ext in (".png", ".jpg", ".jpeg", ".webp"):
        shutil.copyfile(wall, os.path.join(out, "background" + ext))
        print("background=background" + ext)
EOF

font="$(fc-match -f '%{file}' 'Inter:weight=500' 2>/dev/null || true)"
if [[ -f "$font" && "$(fc-query -f '%{family[0]}\n' "$font" 2>/dev/null | head -1)" == Inter ]]; then
    cp "$font" "$stage/isla/Inter.ttf"
    echo "font=Inter.ttf" >> "$stage/isla/theme.conf"
fi
locale="${LANG%%.*}"
[[ $locale =~ ^[a-z]{2}(_[A-Z]{2})?$ ]] || locale=es_ES
printf 'locale=%s\nclock12h=false\n' "$locale" >> "$stage/isla/theme.conf"

previous="$(current_theme)"
[[ $previous == isla ]] && previous="$(cat "$theme_dir/previous-theme" 2>/dev/null || true)"
[[ $previous =~ ^[A-Za-z0-9._-]+$ ]] && printf '%s\n' "$previous" > "$stage/isla/previous-theme"

set_current "$conf" isla > "$stage/sddm.conf"

# Replace the theme as a whole so stale files (an old wallpaper) do not linger.
"${as_root[@]}" rm -rf -- "$theme_dir"
"${as_root[@]}" install -d -m755 "$theme_dir"
for f in "$stage"/isla/*; do
    "${as_root[@]}" install -m644 "$f" "$theme_dir/"
done
"${as_root[@]}" install -d -m755 "$(dirname -- "$conf")"
"${as_root[@]}" install -m644 "$stage/sddm.conf" "$conf"
printf 'Isla SDDM theme installed (previous: %s). Preview: sddm-greeter-qt6 --test-mode --theme %s\n' \
    "${previous:-none}" "$theme_dir"
