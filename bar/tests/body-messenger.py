#!/usr/bin/env python3
"""Run the messenger Qt regression with a fake opener, never opening real files."""
import os
from pathlib import Path
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix="isla-messenger-") as tmp:
    directory = Path(tmp)
    opener = directory / "xdg-open"
    opener.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$ISLA_MESSENGER_ARGV"\n')
    opener.chmod(0o755)
    env = dict(os.environ, PATH=f"{directory}:{os.environ['PATH']}",
               ISLA_CONFIG=str(directory / "config.json"), QT_QPA_PLATFORM="offscreen",
               ISLA_MESSENGER_ARGV=str(directory / "argv"))
    result = subprocess.run(["quickshell", "-p", "bar/body-messenger-regression.qml"],
                            env=env, capture_output=True, text=True, timeout=45)
    log = result.stdout + result.stderr
    if result.returncode or "Binding loop" in log or "PASS: messenger cycle" not in log:
        print(log)
        raise SystemExit(result.returncode or 1)
    assert (directory / "argv").read_text().splitlines() == [
        "/tmp/messenger $(literal).mp4", "/tmp/reduced.mp4"]
    print("PASS: messenger QML cycle, hidden offers, ownership, transforms, preserved path, reduceMotion")
    print("PASS: fake xdg-open received exactly two literal paths after explicit activation")
