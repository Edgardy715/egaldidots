#!/usr/bin/env python3
"""Force FileView reload after an in-memory notification in an isolated shell."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix="isla-notifs-probe-") as td:
    root = Path(td)
    runtime = root / "runtime"
    runtime.mkdir(mode=0o700)
    state = root / "state/quickshell"
    state.mkdir(parents=True)
    (state / "notifs.json").write_text('{"dnd":false,"notifs":[{"summary":"old"}]}')
    bar = root / "bar"
    shutil.copytree(REPO / "bar", bar)
    notifs = bar / "Singletons/Notifs.qml"
    original = notifs.read_text()
    marker = "    FileView {\n        id: storage"
    assert marker in original
    notifs.write_text(original.replace(marker,
        "    function auditReload(): void { storage.reload() }\n" + marker, 1))
    (bar / "services-notifs-probe.qml").write_text('''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    QtObject {
        id: fresh
        property bool closed: false
        property bool popup: false
        property var notification: ({})
        property string summary: "fresh"
        function _serialize() { return {summary: summary} }
    }
    Timer {
        interval: 100; running: Notifs.loaded
        onTriggered: {
            Notifs.list = [fresh].concat(Notifs.list)
            console.log("AUDIT_NOTIFS_BEFORE=" + Notifs.list.map(n => n.summary).join(","))
            Notifs.auditReload()
        }
    }
    Timer {
        interval: 650; running: true
        onTriggered: {
            console.log("AUDIT_NOTIFS_AFTER=" + Notifs.list.map(n => n.summary).join(","))
        }
    }
    Timer { interval: 1750; running: true; onTriggered: Qt.quit() }
}
''')
    env = dict(os.environ, HOME=str(root), XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(root / "state"),
               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(root / "missing-bus"),
               ISLA_CONFIG=str(root / "shell.json"), QT_QPA_PLATFORM="offscreen")
    result = subprocess.run(["quickshell", "-p", str(bar / "services-notifs-probe.qml")],
                            env=env, capture_output=True, text=True, timeout=5)
    print(result.stdout, end="")
    print(result.stderr, end="")
    saved = __import__("json").loads((state / "notifs.json").read_text())
    print("AUDIT_NOTIFS_PERSISTED=" + ",".join(item.get("summary", "") for item in saved.get("notifs", [])))
    trace = result.stdout + result.stderr
    assert result.returncode == 0 and "AUDIT_NOTIFS_AFTER=fresh,old" in trace, trace
    assert [item.get("summary") for item in saved["notifs"]] == ["fresh", "old"], saved
    print("PASS: live notification survives FileView restoration and persists with history")
    raise SystemExit(result.returncode)
