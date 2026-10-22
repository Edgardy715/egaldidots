#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cargo=$(command -v cargo || true)
if [ -z "$cargo" ] && [ -x "$HOME/.local/share/isla/cargo/bin/cargo" ]; then
    cargo="$HOME/.local/share/isla/cargo/bin/cargo"
    export CARGO_HOME="$HOME/.local/share/isla/cargo"
    export RUSTUP_HOME="$HOME/.local/share/isla/rustup"
fi
[ -n "$cargo" ] || { echo 'Rust toolchain unavailable; Python clipboard fallback remains available.' >&2; exit 1; }
export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/isla/clipboard-list-build"
"$cargo" build --manifest-path "$repo/rust/clipboard-list/Cargo.toml" --release --locked
destination="${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin"
mkdir -p -- "$destination"
temporary=$(mktemp "$destination/.clipboard-list.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
install -m 755 "$CARGO_TARGET_DIR/release/isla-clipboard-list" "$temporary"
mv -f -- "$temporary" "$destination/isla-clipboard-list"
printf 'Installed %s/isla-clipboard-list\n' "$destination"
