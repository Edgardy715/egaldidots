#!/bin/sh
set -eu
services=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
native="${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin/isla-clipboard-list"
if [ -x "$native" ]; then
    exec "$native" list --fallback "$services/clipboard_library.py"
fi
exec python3 "$services/clipboard_library.py" list
