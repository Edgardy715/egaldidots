#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cargo=$(command -v cargo || true)
if [ -z "$cargo" ] && [ -x "$HOME/.local/share/isla/cargo/bin/cargo" ]; then
    cargo="$HOME/.local/share/isla/cargo/bin/cargo"
    export CARGO_HOME="$HOME/.local/share/isla/cargo"
    export RUSTUP_HOME="$HOME/.local/share/isla/rustup"
fi
[ -n "$cargo" ] || { echo 'Rust toolchain unavailable; Python peak fallback remains available.' >&2; exit 1; }
export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/isla/audio-peak-build"
"$cargo" build --manifest-path "$repo/rust/audio-peak/Cargo.toml" --release --locked
destination="${XDG_DATA_HOME:-$HOME/.local/share}/isla/lib"
mkdir -p -- "$destination"
temporary=$(mktemp "$destination/.audio-peak.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
install -m 644 "$CARGO_TARGET_DIR/release/libisla_audio_peak.so" "$temporary"
mv -f -- "$temporary" "$destination/libisla_audio_peak.so"
printf 'Installed %s/libisla_audio_peak.so\n' "$destination"
