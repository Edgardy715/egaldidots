"""Exercise compositor settings UI with an injected backend, never the desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-hyprland-ui-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    (root / "shell.json").write_text('{"appearance":{"reduceMotion":true}}')
    output = Path(os.environ.get("ISLA_TEST_OUTPUT", str(root / "images")))
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, ISLA_CONFIG=str(root / "shell.json"),
               ISLA_HYPRLAND_CONFIG=str(root / "hyprland.json"),
               ISLA_TEST_OUTPUT=str(output), QT_QPA_PLATFORM="wayland")
    result = subprocess.run(["qs", "-p", str(root / "bar/hyprland-settings-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=60)
    print(result.stdout + result.stderr)
    assert result.returncode == 0 and "PASS: Hyprland settings UI" in result.stdout + result.stderr
    assert not (root / "hyprland.json").exists(), "UI mock must not persist compositor settings"
