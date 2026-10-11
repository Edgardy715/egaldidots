#!/bin/sh
set -eu
settings_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
apps_dir=${XDG_DATA_HOME:-$HOME/.local/share}/applications
mkdir -p "$apps_dir"
cat > "$apps_dir/edots-settings.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Edots
Comment=Personaliza Isla
Exec="$settings_dir/open.sh"
Icon=$settings_dir/assets/edots.png
Terminal=false
Categories=Settings;DesktopSettings;
StartupNotify=false
DESKTOP
