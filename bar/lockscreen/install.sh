#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-lockscreen"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/isla"
mkdir -p "$target_dir" "$state_dir"
if [[ -e "$target_dir/lock.sh" ]]; then
    backup_dir="$(mktemp -d "$state_dir/lockscreen-backup.XXXXXX")"
    cp -pL "$target_dir/lock.sh" "$backup_dir/lock.sh"
    printf 'Previous launcher: %s\n' "$backup_dir/lock.sh"
fi
launcher="$(mktemp "$target_dir/.lock.sh.XXXXXX")"
printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$source_dir/lock.sh" > "$launcher"
chmod 755 "$launcher"
mv -f "$launcher" "$target_dir/lock.sh"
printf 'Installed launcher: %s\n' "$target_dir/lock.sh"
