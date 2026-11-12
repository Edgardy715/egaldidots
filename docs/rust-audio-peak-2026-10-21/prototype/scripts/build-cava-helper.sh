#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cargo=$(command -v cargo || true)
if [ -z "$cargo" ] && [ -x "$HOME/.local/share/isla/cargo/bin/cargo" ]; then
    cargo="$HOME/.local/share/isla/cargo/bin/cargo"
    export CARGO_HOME="$HOME/.local/share/isla/cargo"
    export RUSTUP_HOME="$HOME/.local/share/isla/rustup"
fi
[ -n "$cargo" ] || { echo 'Rust toolchain unavailable; Python fallback remains available.' >&2; exit 1; }
export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/isla/cava-stream-build"
"$cargo" build --manifest-path "$repo/rust/cava-stream/Cargo.toml" --release --locked
destination="${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin"
mkdir -p -- "$destination"
temporary=$(mktemp "$destination/.cava-stream.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
install -m 755 "$CARGO_TARGET_DIR/release/isla-cava-stream" "$temporary"
mv -f -- "$temporary" "$destination/isla-cava-stream"
printf 'Installed %s/isla-cava-stream\n' "$destination"
