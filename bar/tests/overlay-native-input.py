"""Exercise compositor keyboard delivery; never activate system actions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-native-input-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    config = root / "shell.json"
    config.write_text(json.dumps({"appearance": {"reduceMotion": True}}))
    fixture = root / "bar/overlay-native-input-regression.qml"
    env = dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM="wayland")
    with (root / "output.log").open("w+") as log:
        process = subprocess.Popen(["qs", "-p", str(fixture)], env=env, stdout=log, stderr=subprocess.STDOUT)
        def call(method, *args):
            return subprocess.run(["qs", "-p", str(fixture), "ipc", "call", "nativeInputTest", method, *args],
                                  env=env, capture_output=True, text=True, timeout=5)
        def wait_surface(name):
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                result = call("state")
                if result.returncode == 0:
                    state = json.loads(result.stdout)
                    if state["surface"] == name:
                        assert state["wantsKeyboard"] == bool(name), state
                        return
                assert process.poll() is None, "fixture exited before checking native input"
                time.sleep(.04)
            raise AssertionError("native keyboard route did not reach " + repr(name))
        try:
            wait_surface("")
            for name in ["calendar", "mixer", "connectivity", "workspaces", "notifs", "utils", "appearance",
                         "launcher", "media", "wallpaper", "clipboard", "overview", "session", "settings"]:
                assert call("open", name).returncode == 0
                wait_surface(name)
                time.sleep(.15)
                subprocess.run(["wtype", "-k", "Escape"], env=env, check=True, timeout=3)
                wait_surface("")
                print("PASS native open/Escape/focus release:", name, flush=True)
            log.flush()
            log.seek(0)
            output = log.read()
            assert not any(word in output for word in ["FAIL", "TypeError", "ReferenceError", "Binding loop"]), output
            print("PASS: all 14 non-auth modal surfaces receive Wayland Escape and release keyboard on close")
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            process.terminate()
            process.wait(timeout=5)
