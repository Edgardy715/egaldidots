"""Check settings layout, accessibility contracts and form feedback in isolation."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-settings-ux-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    (root / "config.json").write_text("{}")
    env = dict(os.environ, ISLA_CONFIG=str(root / "config.json"),
               XDG_STATE_HOME=str(root / "state"), QT_QPA_PLATFORM="wayland")
    with (root / "output.log").open("w+") as log:
        result = subprocess.run(["qs", "-p", str(root / "bar/settings-ux-regression.qml")],
                                env=env, stdout=log, stderr=log, timeout=65)
        log.seek(0)
        output = log.read()
        print(output)
        assert result.returncode == 0 and "FAIL" not in output and "PASS: settings UX" in output
