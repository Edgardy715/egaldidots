#!/usr/bin/env python3
"""List launcher exec ownership and optional locked atomic installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="isla clipboard $ spaces ") as directory:
    temp = Path(directory)
    services = temp / "services"
    services.mkdir()
    launcher = services / "clipboard-list.sh"
    shutil.copy2(ROOT / "bar/services/clipboard-list.sh", launcher)
    recorder = "import json,os,sys; print(json.dumps({'pid':os.getpid(),'args':sys.argv[1:]}))\n"
    python = services / "clipboard_library.py"
    python.write_text(recorder)
    data = temp / "data"
    env = {**os.environ, "XDG_DATA_HOME": str(data), "XDG_CACHE_HOME": str(temp / "cache")}
    for native_present in (False, True):
        native = data / "isla/bin/isla-clipboard-list"
        if native_present:
            native.parent.mkdir(parents=True)
            native.write_text("#!/usr/bin/python3\n" + recorder)
            native.chmod(0o755)
        process = subprocess.Popen(["sh", str(launcher)], env=env, stdout=subprocess.PIPE)
        output, _ = process.communicate(timeout=3)
        assert process.returncode == 0
        expected = ["list", "--fallback", str(python)] if native_present else ["list"]
        assert json.loads(output) == {"pid": process.pid, "args": expected}
    fake_bin = temp / "bin"
    fake_bin.mkdir()
    cargo = fake_bin / "cargo"
    cargo.write_text('''#!/bin/sh
set -eu
[ "$1" = build ]
[ "$2" = --manifest-path ]
[ "$4" = --release ]
[ "$5" = --locked ]
mkdir -p "$CARGO_TARGET_DIR/release"
printf 'replacement' > "$CARGO_TARGET_DIR/release/isla-clipboard-list"
''')
    cargo.chmod(0o755)
    env["PATH"] = str(fake_bin) + os.pathsep + env["PATH"]
    script = ROOT / "scripts/build-clipboard-list.sh"
    subprocess.run(["sh", str(script)], env=env, check=True)
    assert native.read_bytes() == b"replacement" and native.stat().st_mode & 0o777 == 0o755
    assert not list(native.parent.glob(".clipboard-list.*"))
    cargo.write_text("#!/bin/sh\nexit 17\n")
    assert subprocess.run(["sh", str(script)], env=env).returncode == 17
    assert native.read_bytes() == b"replacement"
    cargo.write_text('#!/bin/sh\nrm -f "$CARGO_TARGET_DIR/release/isla-clipboard-list"\n')
    assert subprocess.run(["sh", str(script)], env=env).returncode != 0
    assert native.read_bytes() == b"replacement"
    assert not list(native.parent.glob(".clipboard-list.*"))
print("PASS: native/fallback exec, same PID/argv, paths with spaces/metacharacters, atomic build/copy failure")
