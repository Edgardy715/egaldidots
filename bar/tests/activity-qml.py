#!/usr/bin/env python3
"""Run activity or existing QML fixtures without the user's shell/runtime/config."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
failed = False
for fixture in sys.argv[1:] or ["bar/activities-regression.qml"]:
    with tempfile.TemporaryDirectory(prefix="isla-activity-test-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "state", "home"):
            (base / name).mkdir(mode=0o700)
        runtime = str(base / "runtime")
        env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "home/.config"),
                   XDG_RUNTIME_DIR=runtime, XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
                   ISLA_CONFIG=str(base / "missing.json"), ISLA_ACTIVITY_SOCKET_TEST=runtime,
                   QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_CONTROLS_STYLE="Basic")
        for name in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"):
            env.pop(name, None)
        result = subprocess.run(["timeout", "90", "quickshell", "-p", str(root / fixture)],
                                cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        markers = [line for line in result.stdout.splitlines() if any(word in line for word in ("PASS:", "FAIL:", "BLOCKED:"))]
        bad = result.returncode != 0 or not any("PASS:" in line for line in markers) or any("FAIL:" in line for line in markers)
        failed |= bad
        print(f"{fixture}: exit={result.returncode}, {'FAIL' if bad else 'PASS'}", flush=True)
        print("\n".join(markers), flush=True)
        if any("BLOCKED:" in line for line in markers):
            print("\n".join(line for line in result.stdout.splitlines() if "BLOCKED:" not in line and "socket" in line.lower()
                            and any(word in line.lower() for word in ("failed", "error", "unable"))), flush=True)
        if bad:
            print(result.stdout[-16000:], flush=True)
raise SystemExit(1 if failed else 0)
