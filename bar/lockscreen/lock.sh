#!/usr/bin/env bash
set -u

lock_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
export QML_IMPORT_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/isla/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
unset ISLA_LOCK_SNAPSHOT_DIR QS_LOCK_PREVIEW_SNAPSHOT QS_LOCK_PREVIEW QS_LOCK_PREVIEW_SHOT QS_LOCK_PREVIEW_WIDTH QS_LOCK_PREVIEW_HEIGHT QS_LOCK_PREVIEW_DELAY

# hypridle, loginctl and Super+L may request a lock at the same time.
exec 9>"$runtime_dir/isla-lock-${UID}.lock"
flock -n 9 || exit 0

# One frame per output so the lock can grow out of the desktop and return to it.
# Private to the user (tmpfs under XDG_RUNTIME_DIR) and removed when the lock ends.
snapshot_dir=""
cleanup() { [[ -n "$snapshot_dir" ]] && rm -rf -- "$snapshot_dir"; }
trap cleanup EXIT
if command -v grim >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    snapshot_dir="$(umask 077; mktemp -d "$runtime_dir/isla-lock-snap.XXXXXX" 2>/dev/null)" || snapshot_dir=""
    if [[ -n "$snapshot_dir" ]]; then
        while IFS= read -r output; do
            [[ "$output" =~ ^[A-Za-z0-9._-]+$ ]] || continue
            (umask 077; timeout 1 grim -o "$output" -t ppm "$snapshot_dir/$output.ppm" 2>/dev/null) || rm -f -- "$snapshot_dir/$output.ppm"
        done < <(timeout 1 hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
        export ISLA_LOCK_SNAPSHOT_DIR="$snapshot_dir"
    fi
fi

quickshell --path "$lock_dir/../lockscreen.qml"
result=$?
cleanup
snapshot_dir=""

# If Quickshell could not create a session lock, retain a working lock screen.
if (( result != 0 )) && command -v hyprlock >/dev/null 2>&1; then
    exec hyprlock
fi

exit "$result"
