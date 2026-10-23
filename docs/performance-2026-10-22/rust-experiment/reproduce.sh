#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
evidence="$repo/docs/performance-2026-10-22/rust-experiment"
target=${1:-/tmp/isla-cava-b}
if [ ! -f "$target/Cargo.toml" ]; then
    mkdir -p "$target"
    cp "$repo/rust/cava-stream/Cargo.toml" "$repo/rust/cava-stream/Cargo.lock" "$target/"
    cp -r "$repo/rust/cava-stream/src" "$target/"
    patch -d "$target" -p1 < "$evidence/main.patch"
fi
cp "$evidence/spectrum.rs" "$target/src/spectrum.rs"
node "$evidence/generate-vectors.cjs"
cp "$evidence/vectors.json" "$target/vectors.json"
cargo=$(command -v cargo || true)
if [ -z "$cargo" ]; then
    cargo="$HOME/.local/share/isla/cargo/bin/cargo"
    export CARGO_HOME="$HOME/.local/share/isla/cargo"
    export RUSTUP_HOME="$HOME/.local/share/isla/rustup"
fi
"$cargo" test --manifest-path "$target/Cargo.toml" --locked
"$cargo" clippy --manifest-path "$target/Cargo.toml" --locked --all-targets -- -D warnings
"$cargo" build --manifest-path "$target/Cargo.toml" --release --locked
printf '%s\n' "$target/target/release/isla-cava-stream"
