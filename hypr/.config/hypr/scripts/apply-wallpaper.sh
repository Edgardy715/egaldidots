#!/usr/bin/env bash
# Keep the picker/Isla entry point stable; generate.py owns the transaction.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
generator="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/generate.py"
if [[ ! -f "$generator" ]]; then
    generator="$script_dir/../../../../matugen/.config/matugen/generate.py"
fi
exec python3 "$generator" "$@"
