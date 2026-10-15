"""Exercise startup loading without connecting to any compositor."""
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile

launcher = Path(__file__).with_name("scrolloverview-load.sh")
with tempfile.TemporaryDirectory(prefix="isla-overview-loader-") as directory:
    root = Path(directory)
    plugin = root / "data/isla/scrolloverview/scrolloverview.so"
    plugin.parent.mkdir(parents=True)
    fake = root / "hyprctl"
    fake.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$FAKE_CALLS"
if [ "$1 $2" = "plugin list" ]; then
    [ "$FAKE_MODE" != "ipc-fail" ] || exit 4
    [ "$FAKE_MODE" != "loaded" ] && [ "$FAKE_MODE" != "dispatch-fail" ] || echo 'Plugin scrolloverview by Vaxry, yayuuu:'
    exit 0
fi
[ "$1" != "dispatch" ] || [ "$FAKE_MODE" != "dispatch-fail" ] || exit 6
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
    assert code == 0 and commands == ["plugin list", "plugin load " + str(plugin)]
    code, commands = run(FAKE_MODE="loaded")
    assert code == 0 and commands == ["plugin list"], "already loaded must not reload"
    assert run(FAKE_MODE="ipc-fail")[0] != 0
    assert run(FAKE_MODE="load-fail")[0] != 0
    with (root / "isla-scrolloverview-fixture.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert run() == (0, []), "duplicate startup must not connect or load"
    fake_qs = root / "qs"
    fake_qs.write_text('#!/bin/sh\nprintf "qs:%s\\n" "$*" >> "$FAKE_CALLS"\n')
    fake_qs.chmod(0o755)
    for script, action in [("scrolloverview-toggle.sh", "toggle"), ("scrolloverview-isla.sh", "off")]:
        calls.write_text("")
        subprocess.run([str(launcher.with_name(script))], env=dict(env, FAKE_MODE="loaded"), check=True)
        commands = calls.read_text().splitlines()
        dispatch = 'dispatch hl.plugin.scrolloverview.overview("' + action + '")'
        if action == "toggle":
            assert commands == ["plugin list", "qs:-c bar ipc call island hide", dispatch]
        else:
            assert commands == ["plugin list", dispatch, "qs:-c bar ipc call island overview "]
        calls.write_text("")
        subprocess.run([str(launcher.with_name(script))], env=env, check=True)
        assert calls.read_text().splitlines() == ["plugin list", "qs:-c bar ipc call island overview "]
    calls.write_text("")
    failed = subprocess.run([str(launcher.with_name("scrolloverview-toggle.sh"))], env=dict(env, FAKE_MODE="dispatch-fail"))
    assert failed.returncode != 0
    assert calls.read_text().splitlines()[-1].startswith("dispatch "), "unknown plugin state must not open a second overview"
print("PASS: overview loader guards/errors and ordered Niri/Isla routes with plugin fallback")
