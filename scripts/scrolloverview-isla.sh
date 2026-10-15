#!/usr/bin/env bash
set -euo pipefail

plugins=$(timeout 2 hyprctl plugin list) || exit 1
if [[ "$plugins" == *"Plugin scrolloverview by"* ]]; then
    timeout 3 hyprctl dispatch 'hl.plugin.scrolloverview.overview("off")' || exit 1
fi
exec timeout 3 qs -c bar ipc call island overview ""
