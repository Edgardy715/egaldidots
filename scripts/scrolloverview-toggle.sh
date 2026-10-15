#!/usr/bin/env bash
set -euo pipefail

plugins=$(timeout 2 hyprctl plugin list) || exit 1
if [[ "$plugins" != *"Plugin scrolloverview by"* ]]; then
    exec timeout 3 qs -c bar ipc call island overview ""
fi

timeout 2 qs -c bar ipc call island hide >/dev/null 2>&1 || true
timeout 3 hyprctl dispatch 'hl.plugin.scrolloverview.overview("toggle")'
