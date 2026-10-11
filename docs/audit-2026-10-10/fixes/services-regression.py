#!/usr/bin/env python3
"""Isolated service regressions; no real network, lock, or clipboard mutation."""
import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[3]


def write(path, content, executable=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    if executable:
        path.chmod(0o700)


def setup(root):
    for part in ("runtime", "home", "data", "bin"):
        (root / part).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, HOME=str(root / "home"), XDG_RUNTIME_DIR=str(root / "runtime"),
               XDG_DATA_HOME=str(root / "data"), ISLA_CONFIG=str(root / "config.json"),
               QT_QPA_PLATFORM="offscreen", PATH=str(root / "bin") + os.pathsep + os.environ["PATH"])
    bar = root / "bar"
    shutil.copytree(REPO / "bar", bar)
    return env, bar


def run(bar, env, qml, timeout=8):
    write(bar / "services-regression.qml", qml)
    result = subprocess.run(["quickshell", "-p", str(bar / "services-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=timeout)
    assert result.returncode == 0, (result.stdout, result.stderr)
    return result.stdout + result.stderr


with tempfile.TemporaryDirectory(prefix="isla-services-regression-") as td:
    root = Path(td) / "wifi"
    env, bar = setup(root)
    env["FAKE_NMCLI_LOG"] = str(root / "nmcli.log")
    write(root / "bin/nmcli", '''#!/bin/sh
printf '%s\\n' "$*" >> "$FAKE_NMCLI_LOG"
case "$1 $2 $3" in
"monitor  ") sleep 2 ;;
"device wifi connect") exit 10 ;;
esac
exit 1
''', True)
    trace = run(bar, env, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    Timer { interval: 200; running: true; onTriggered: Nmcli.connectWithPassword(
        {ssid: "Casa", bssid: "AA:BB:CC:DD:EE:FF"}, "incorrecta", function(result) {
            console.log("WIFI_RESULT=" + result.success)
        }) }
    Timer { interval: 1700; running: true; onTriggered: Qt.quit() }
}
''')
    calls = (root / "nmcli.log").read_text().splitlines()
    assert "WIFI_RESULT=false" in trace, trace
    assert any(c.startswith("device wifi connect Casa password incorrecta bssid AA:BB:CC:DD:EE:FF") for c in calls), calls
    assert not any(c.startswith(("connection delete", "connection add")) for c in calls), calls
    print("SVC01 PASS: failed fake connect returned false; no saved profile delete/add; calls=" + " | ".join(calls))

    root = Path(td) / "wifi-success"
    env, bar = setup(root)
    env["FAKE_NMCLI_LOG"] = str(root / "nmcli.jsonl")
    write(root / "bin/nmcli", '''#!/usr/bin/python3
import json, os, sys, time
args = sys.argv[1:]
with open(os.environ["FAKE_NMCLI_LOG"], "a") as output:
    output.write(json.dumps(args) + "\\n")
if args == ["monitor"]: time.sleep(2)
elif args[:3] == ["device", "wifi", "connect"]: sys.exit(0)
elif args == ["-t", "-f", "NAME,TYPE", "connection", "show"]:
    print("Casa con espacio:802-11-wireless")
else: sys.exit(1)
''', True)
    trace = run(bar, env, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    property int callbackCount: 0
    Timer { interval: 200; running: true; onTriggered: Nmcli.connectWithPassword(
        {ssid: "Casa con espacio", bssid: "aa:bb:cc:dd:ee:ff"}, "clave con espacio", function(result) {
            callbackCount++
            console.log("WIFI_SUCCESS=" + result.success + " count=" + callbackCount)
        }) }
    Timer { interval: 1800; running: true; onTriggered: Qt.quit() }
}
''')
    calls = [json.loads(line) for line in (root / "nmcli.jsonl").read_text().splitlines()]
    expected = ["device", "wifi", "connect", "Casa con espacio", "password", "clave con espacio",
                "bssid", "AA:BB:CC:DD:EE:FF"]
    assert expected in calls and calls.count(expected) == 1, calls
    assert ["-t", "-f", "NAME,TYPE", "connection", "show"] in calls, calls
    assert "WIFI_SUCCESS=true count=1" in trace and "count=2" not in trace, trace
    assert not any(c[:2] == ["connection", "delete"] for c in calls), calls
    print("SVC01 PASS: successful fake connect kept SSID/password as single argv elements, normalized BSSID, callback once, saved refresh")

    root = Path(td) / "session"
    env, bar = setup(root)
    env["FAKE_LOCK_MARKER"] = str(root / "invoked")
    write(root / "data/quickshell-lockscreen/lock.sh",
          '#!/bin/sh\nprintf invoked > "$FAKE_LOCK_MARKER"\n', True)
    trace = run(bar, env, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    Timer { interval: 100; running: true; onTriggered: { Session.lock(); console.log("LOCK_CALLED") } }
    Timer { interval: 900; running: true; onTriggered: Qt.quit() }
}
''')
    assert "LOCK_CALLED" in trace and (root / "invoked").read_text() == "invoked", trace
    print("SVC02 PASS: Session.lock executed only temporary XDG_DATA_HOME wrapper")

    root = Path(td) / "session-fallback"
    env, bar = setup(root)
    env.pop("XDG_DATA_HOME")
    env["FAKE_LOCK_MARKER"] = str(root / "invoked")
    write(root / "home/.local/share/quickshell-lockscreen/lock.sh",
          '#!/bin/sh\nprintf invoked > "$FAKE_LOCK_MARKER"\n', True)
    trace = run(bar, env, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    Timer { interval: 100; running: true; onTriggered: { Session.lock(); console.log("FALLBACK_CALLED") } }
    Timer { interval: 900; running: true; onTriggered: Qt.quit() }
}
''')
    assert "FALLBACK_CALLED" in trace and (root / "invoked").read_text() == "invoked", trace
    print("SVC02 PASS: absent XDG_DATA_HOME uses temporary HOME fallback")

    root = Path(td) / "clipboard"
    env, bar = setup(root)
    image = root / "image.png"
    subprocess.run(["magick", "-size", "64x32", "xc:steelblue", str(image)], check=True)
    env["FAKE_CLIP_IMAGE"] = str(image)
    env["FAKE_CLIP_MODE"] = "success"
    write(root / "bin/cliphist", '''#!/bin/sh
case "$1" in
list) printf '2\\t[[ binary data png ]]\\n' ;;
decode) if [ "$FAKE_CLIP_MODE" = slow ]; then sleep 2; fi; cat "$FAKE_CLIP_IMAGE" ;;
wipe) [ "$FAKE_CLIP_MODE" != failure ] ;;
esac
''', True)
    fixture = '''import QtQuick
import Quickshell
import "surfaces"
ShellRoot {
    Window {
        visible: true; width: 620; height: 540
        ClipboardSurface { id: surface; anchors.fill: parent; open: true }
        Timer { interval: 1200; running: true; onTriggered: surface.clearHistory() }
        Timer { interval: 2700; running: true; onTriggered: {
            console.log("CLEAR_RESULT entries=" + surface.entries.length + " clearing=" + surface.clearing
                + " error=" + surface.errorMessage)
        } }
        Timer { interval: 3900; running: true; onTriggered: Qt.quit() }
    }
}
'''
    for mode in ("success", "failure", "slow"):
        env["FAKE_CLIP_MODE"] = mode
        write(bar / "services-regression.qml", fixture)
        proc = subprocess.Popen(["quickshell", "-p", str(bar / "services-regression.qml")],
                                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        time.sleep(3.2)
        previews = list((root / "runtime").glob("isla-clipboard.*/*.png"))
        assert proc.poll() is None
        stdout, stderr = proc.communicate(timeout=4)
        trace = stdout + stderr
        assert proc.returncode == 0 and "CLEAR_RESULT" in trace, trace
        if mode in ("success", "slow"):
            assert "entries=0 clearing=false" in trace and not previews, (trace, previews)
        else:
            assert "entries=1 clearing=false" in trace and previews, (trace, previews)
        print(f"SVC04 PASS: fake wipe {mode}; PNG count while surface alive={len(previews)}")

print("All cases used a temporary bar copy and HOME/XDG/PATH; no real service was called.")
