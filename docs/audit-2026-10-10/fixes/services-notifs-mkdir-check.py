#!/usr/bin/env python3
"""Delay state directory creation in an isolated copy; verify queued save."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix="isla-notifs-mkdir-") as td:
    root = Path(td)
    for part in ("runtime", "bin"):
        (root / part).mkdir()
    fake = root / "bin/mkdir"
    fake.write_text('#!/bin/sh\nsleep 1.4\nexec /usr/bin/mkdir "$@"\n')
    fake.chmod(0o700)
    bar = root / "bar"
    shutil.copytree(REPO / "bar", bar)
    (bar / "services-notifs-mkdir.qml").write_text('''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    QtObject {
        id: fresh
        property bool closed: false
        property bool popup: false
        property var notification: ({})
        property string summary: "during-mkdir"
        function _serialize() { return {summary: summary} }
    }
    Timer { interval: 100; running: true; onTriggered: {
        Notifs.list = [fresh]
        console.log("MKDIR_EARLY loaded=" + Notifs.loaded + " ready=" + Notifs.stateReady)
    } }
    Timer { interval: 2750; running: true; onTriggered: {
        console.log("MKDIR_LATE loaded=" + Notifs.loaded + " ready=" + Notifs.stateReady
            + " pending=" + Notifs.pendingSave)
        Qt.quit()
    } }
}
''')
    env = dict(os.environ, HOME=str(root), XDG_RUNTIME_DIR=str(root / "runtime"),
               XDG_STATE_HOME=str(root / "state"),
               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(root / "missing-bus"),
               ISLA_CONFIG=str(root / "config.json"), QT_QPA_PLATFORM="offscreen",
               PATH=str(root / "bin") + os.pathsep + os.environ["PATH"])
    result = subprocess.run(["quickshell", "-p", str(bar / "services-notifs-mkdir.qml")],
                            env=env, capture_output=True, text=True, timeout=6)
    trace = result.stdout + result.stderr
    assert result.returncode == 0 and "ready=false" in trace, trace
    assert "MKDIR_LATE loaded=true ready=true pending=false" in trace, trace
    saved = json.loads((root / "state/quickshell/notifs.json").read_text())
    assert [item["summary"] for item in saved["notifs"]] == ["during-mkdir"], saved
    print("SVC03 PASS: delayed fake mkdir, early notification retained and persisted after directory exists")
