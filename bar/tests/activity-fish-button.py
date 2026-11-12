#!/usr/bin/env python3
"""Exercise FishIntegration's real buttons with an isolated temporary HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
fixture = ROOT / "bar/tests/activity-fish-button.qml"
source = ROOT / "bar/scripts/fish/isla.fish"
quickshell = shutil.which("quickshell")
if not quickshell:
    raise SystemExit("BLOCKED: quickshell executable unavailable")

with tempfile.TemporaryDirectory(prefix="isla-fish-button-") as temp:
    base = Path(temp)
    home = base / "home"
    runtime = base / "runtime"
    cache = base / "cache"
    state = base / "state"
    for directory in (home, runtime, cache, state):
        directory.mkdir()
    target = home / ".config/fish/conf.d/isla.fish"
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
               XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(cache), ISLA_CONFIG=str(base / "missing.json"),
               XDG_STATE_HOME=str(state),
               QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_CONTROLS_STYLE="Basic")
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def invoke(mode):
        result = subprocess.run(["timeout", "20", quickshell, "-p", str(fixture)],
                                env=dict(env, ISLA_FISH_TEST_MODE=mode,
                                         ISLA_TEST_COMPONENT=str(ROOT / "bar/settings/FishIntegration.qml")),
                                capture_output=True, text=True, timeout=25)
        if result.returncode:
            raise SystemExit(f"BLOCKED: fixture {mode} failed ({result.returncode})\n{result.stdout}\n{result.stderr}")

    invoke("install")
    assert target.is_symlink() and target.resolve() == source.resolve(), "install button did not create expected symlink"
    invoke("remove")
    assert not target.exists() and not target.is_symlink(), "remove button did not remove expected symlink"
print("PASS FishIntegration buttons create/remove expected symlink under temporary HOME")
