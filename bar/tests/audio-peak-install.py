#!/usr/bin/env python3
"""Atomic optional peak library installation, including failed build/copy."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/build-audio-peak.sh"
with tempfile.TemporaryDirectory(prefix="isla peak install ") as tmp:
    temp = Path(tmp)
    binary = temp / "bin"
    binary.mkdir()
    cargo = binary / "cargo"
    env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"],
           "XDG_DATA_HOME": str(temp / "data with spaces"), "XDG_CACHE_HOME": str(temp / "cache")}
    target = Path(env["XDG_DATA_HOME"]) / "isla/lib/libisla_audio_peak.so"
    cargo.write_text('''#!/bin/sh
set -eu
[ "$1" = build ]
[ "$2" = --manifest-path ]
[ "$4" = --release ]
[ "$5" = --locked ]
mkdir -p "$CARGO_TARGET_DIR/release"
printf 'new library' > "$CARGO_TARGET_DIR/release/libisla_audio_peak.so"
''')
    cargo.chmod(0o755)
    subprocess.run(["sh", str(SCRIPT)], env=env, check=True)
    assert target.read_bytes() == b"new library"
    assert target.stat().st_mode & 0o777 == 0o644
    assert not list(target.parent.glob(".audio-peak.*"))
    target.write_bytes(b"old library")
    cargo.write_text("#!/bin/sh\nexit 17\n")
    assert subprocess.run(["sh", str(SCRIPT)], env=env).returncode == 17
    assert target.read_bytes() == b"old library"
    cargo.write_text('#!/bin/sh\nrm -f "$CARGO_TARGET_DIR/release/libisla_audio_peak.so"\n')
    assert subprocess.run(["sh", str(SCRIPT)], env=env).returncode != 0
    assert target.read_bytes() == b"old library"
    assert not list(target.parent.glob(".audio-peak.*"))
print("PASS: locked build, XDG paths/spaces, mode, atomic replace, build/copy failures preserve old library")
