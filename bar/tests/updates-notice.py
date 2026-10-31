"""Real notifier integration on a private bus and state directory; no user notices."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-updates-notice-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    (root / "shell.json").write_text('{"updates":{"enabled":false}}')
    env = dict(os.environ, ISLA_CONFIG=str(root / "shell.json"),
               XDG_STATE_HOME=str(root / "state"), QT_QPA_PLATFORM="offscreen")
    for replay in ("0", "1"):
        result = subprocess.run(["dbus-run-session", "--", "qs", "-p", str(root / "bar/updates-notice-regression.qml")],
                                env=dict(env, ISLA_TEST_REPLAY=replay), capture_output=True, text=True, timeout=15)
        log = result.stdout + result.stderr
        print(log)
        assert result.returncode == 0 and "PASS: Updates notice" in log and "FAIL" not in log
