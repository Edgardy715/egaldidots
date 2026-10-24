#!/usr/bin/env python3
"""Exercise pet lifecycle/input in an isolated config; optionally retain visual QA."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path)
args = parser.parse_args()
bar = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-pets-") as directory:
    root = Path(directory)
    config = root / "shell.json"
    config.write_text("{}")
    env = dict(os.environ, ISLA_CONFIG=str(config),
               QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "offscreen"))
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        env["ISLA_TEST_OUTPUT"] = str(args.output.resolve())
    for fixture, marker in (("pets-regression.qml", "PASS: pets layouts"),
                            ("pets-overlay-regression.qml", "PASS: pets production composition"),
                            ("pets-media-regression.qml", "PASS: pets media baseline")):
        result = subprocess.run(["quickshell", "-p", str(bar / fixture)],
                                env=env, capture_output=True, text=True, timeout=35)
        log = result.stdout + result.stderr
        if args.output:
            (args.output / (fixture + ".log")).write_text(log)
        print(log)
        assert result.returncode == 0, "fixture failed: " + fixture
        assert marker in log and "FAIL" not in log, "fixture did not pass: " + fixture
        assert "Error:" not in log and "ReferenceError" not in log, "QML load/binding error"
