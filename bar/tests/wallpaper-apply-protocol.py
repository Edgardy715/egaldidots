"""Run the real QML process/parser contract with a fake applicator, offscreen."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="isla-apply-protocol-") as directory:
    base = Path(directory)
    script = base / "apply.sh"
    script.write_text('''#!/bin/bash
[[ "$2" == --isla-feedback ]] || exit 8
printf 'ISLA_WALLPAPER_HANDOFF\\n'
sleep 0.08
[[ "$1" != *fail* ]] || exit 3
exit 0
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", ISLA_CONFIG=str(base / "config.json"),
               ISLA_TEST_APPLY_SCRIPT=str(script))
    result = subprocess.run(["quickshell", "-p", str(root / "bar/wallpaper-apply-protocol-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "PASS:" in output and "FAIL:" not in output, output
    print("PASS: real QML applicator stdout handoff, busy, partial failure and feedback release")
