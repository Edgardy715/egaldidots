#!/bin/sh
# exec keeps Quickshell as the direct owner of either backend.
set -eu
parent=$1
shift
native="${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin/isla-cava-stream"
if [ -x "$native" ]; then
    exec "$native" --parent "$parent" "$@"
fi
exec python3 "$(dirname -- "$0")/cava_stream.py" "$@"
