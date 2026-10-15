"""Exercise logout command selection without closing any real session."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / "Singletons/Session.qml"
match = re.search(r'readonly property string logoutCmd: (".*")', source.read_text())
command = json.loads(match.group(1))
with tempfile.TemporaryDirectory(prefix="isla-session-logout-") as directory:
    root = Path(directory)
    calls = root / "calls"
    for name, script in {
        "uwsm": 'if [ "$1" = check ]; then exit "$MOCK_UWSM_ACTIVE"; fi\nprintf "uwsm:%s\\n" "$*" >> "$MOCK_CALLS"',
        "loginctl": 'printf "loginctl:%s\\n" "$*" >> "$MOCK_CALLS"',
    }.items():
        target = root / name
        target.write_text("#!/bin/sh\n" + script + "\n")
        target.chmod(0o755)
    env = dict(os.environ, PATH=str(root), MOCK_CALLS=str(calls), XDG_SESSION_ID="42")

    def check(active, expected):
        calls.write_text("")
        result = subprocess.run(["/bin/sh", "-c", command],
                                env=dict(env, MOCK_UWSM_ACTIVE=str(active)),
                                capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert calls.read_text() == expected, calls.read_text()

    check(0, "uwsm:stop\n")
    check(1, "loginctl:terminate-session 42\n")
    (root / "uwsm").unlink()
    check(1, "loginctl:terminate-session 42\n")
    calls.write_text("")
    env.pop("XDG_SESSION_ID")
    result = subprocess.run(["/bin/sh", "-c", command], env=env,
                            capture_output=True, text=True)
    assert result.returncode != 0 and not calls.read_text()
print("PASS: UWSM logout, unmanaged fallback, absent UWSM and missing session ID")
