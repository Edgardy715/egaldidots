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

# Fail-safe: never leave a lock request unlocked. Hyprland reports the real state
# (`hyprctl -j locked`); without it, fall back to the exit code as before.
session_locked() { timeout 1 hyprctl -j locked 2>/dev/null | grep -q '"locked": *true'; }
can_verify=0
# hyprctl answers "unknown request" (exit 0) on Hyprland without `locked`.
command -v hyprctl >/dev/null 2>&1 \
    && timeout 1 hyprctl -j locked 2>/dev/null | grep -q '"locked": *\(true\|false\)' && can_verify=1

# Someone else (hyprlock, a previous lock) already holds the session.
if (( can_verify )) && session_locked; then
    exit 0
fi

fallback() {
    command -v hyprlock >/dev/null 2>&1 && exec hyprlock
    printf 'isla lock: lock screen failed and hyprlock is not installed\n' >&2
    exit 1
}

# No crash handler: a relaunched lockscreen would race hyprlock unsupervised.
# Close the flock fd so only lock.sh (and hyprlock after exec) holds it.
QS_DISABLE_CRASH_HANDLER=1 quickshell --path "$lock_dir/../lockscreen.qml" 9>&- &
qs_pid=$!

if (( can_verify )); then
    # Wait for the session lock; Quickshell exiting first or never locking is a failure.
    confirm=${ISLA_LOCK_CONFIRM_SECONDS:-5}
    [[ $confirm =~ ^[0-9]+$ ]] || confirm=5
    deadline=$(( SECONDS + confirm ))
    until session_locked; do
        if ! kill -0 "$qs_pid" 2>/dev/null || (( SECONDS >= deadline )); then
            kill "$qs_pid" 2>/dev/null
            wait "$qs_pid" 2>/dev/null
            cleanup
            snapshot_dir=""
            fallback
        fi
        sleep 0.1
    done
fi

wait "$qs_pid"
result=$?
cleanup
snapshot_dir=""

# Quickshell crashed while locked, or could not lock and we could not verify:
# keep a working lock screen.
if (( result != 0 )) || { (( can_verify )) && session_locked; }; then
    fallback
fi

exit "$result"
