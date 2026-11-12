#!/usr/bin/env bash
set -euo pipefail

# Called once from Hyprland's startup event, in a child process. Never load a
# plugin while Hyprland is still evaluating its Lua configuration: in 0.57 the
# load is ignored there. After loading, reload once so glass.lua can configure
# the freshly registered plugin.
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 1
plugin="${XDG_DATA_HOME:-$HOME/.local/share}/isla/hyprglass/hyprglass.so"
[[ -f "$plugin" ]] || exit 1

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/isla-hyprglass-${HYPRLAND_INSTANCE_SIGNATURE}.lock"
flock -n 9 || exit 0
plugins=$(timeout 5 hyprctl plugin list) || exit 1
if [[ "$plugins" == *"Plugin hyprglass by"* ]]; then
    exit 0
fi

timeout 10 hyprctl plugin load "$plugin"
timeout 10 hyprctl reload
