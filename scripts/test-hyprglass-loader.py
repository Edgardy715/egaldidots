"""Exercise hyprglass startup loading without connecting to any compositor."""
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile

launcher = Path(__file__).with_name("hyprglass-load.sh")
with tempfile.TemporaryDirectory(prefix="isla-glass-loader-") as directory:
    root = Path(directory)
    plugin = root / "data/isla/hyprglass/hyprglass.so"
    plugin.parent.mkdir(parents=True)
    fake = root / "hyprctl"
    fake.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$FAKE_CALLS"
if [ "$1 $2" = "plugin list" ]; then
    [ "$FAKE_MODE" != "ipc-fail" ] || exit 4
    [ "$FAKE_MODE" != "loaded" ] || echo 'Plugin hyprglass by Hyprnux:'
    exit 0
fi
[ "$FAKE_MODE" != "load-fail" ] || exit 5
''')
    fake.chmod(0o755)
    calls = root / "calls"
    env = dict(os.environ, PATH=str(root) + ":" + os.environ["PATH"],
               XDG_DATA_HOME=str(root / "data"), XDG_RUNTIME_DIR=str(root),
               HYPRLAND_INSTANCE_SIGNATURE="fixture", FAKE_CALLS=str(calls), FAKE_MODE="empty")

    def run(**changes):
        calls.write_text("")
        result = subprocess.run([str(launcher)], env=dict(env, **changes), capture_output=True, text=True)
        return result.returncode, calls.read_text().splitlines()

    assert run(HYPRLAND_INSTANCE_SIGNATURE="")[0] != 0
    assert run()[0] != 0, "missing binary must not connect"
    plugin.write_bytes(b"fixture")
    code, commands = run()
    assert code == 0 and commands == ["plugin list", "plugin load " + str(plugin), "reload"]
    code, commands = run(FAKE_MODE="loaded")
    assert code == 0 and commands == ["plugin list"], "already loaded must not reload"
    assert run(FAKE_MODE="ipc-fail")[0] != 0
    code, commands = run(FAKE_MODE="load-fail")
    assert code != 0 and "reload" not in commands, "failed load must not reload"
    with (root / "isla-hyprglass-fixture.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert run() == (0, []), "duplicate startup must not connect or load"
print("PASS: hyprglass loader guards, order and errors")
