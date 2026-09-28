#!/usr/bin/env bash
set -u

lock_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
unset QS_LOCK_PREVIEW QS_LOCK_PREVIEW_SHOT QS_LOCK_PREVIEW_WIDTH QS_LOCK_PREVIEW_HEIGHT QS_LOCK_PREVIEW_DELAY

# hypridle, loginctl and Super+L may request a lock at the same time.
exec 9>"$runtime_dir/isla-lock-${UID}.lock"
flock -n 9 || exit 0

quickshell --path "$lock_dir/../lockscreen.qml"
result=$?

# If Quickshell could not create a session lock, retain a working lock screen.
if (( result != 0 )) && command -v hyprlock >/dev/null 2>&1; then
    exec hyprlock
fi

exit "$result"
