#!/usr/bin/env python3
"""Isolated service reproductions; all commands and state remain in TemporaryDirectory."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[3]


def write(path, text, executable=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    if executable:
        path.chmod(0o700)


def environment(root):
    runtime = root / "runtime"
    runtime.mkdir(mode=0o700)
    home = root / "home"
    home.mkdir()
    data = root / "xdg-data"
    data.mkdir()
    bindir = root / "bin"
    bindir.mkdir()
    return dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
                XDG_DATA_HOME=str(data), ISLA_CONFIG=str(root / "shell.json"),
                QT_QPA_PLATFORM="offscreen", PATH=str(bindir) + os.pathsep + os.environ["PATH"])


def shell(root, fixture, env, timeout=8):
    copied = root / "bar"
    shutil.copytree(REPO / "bar", copied)
    write(copied / "services-audit.qml", fixture)
    return subprocess.run(["quickshell", "-p", str(copied / "services-audit.qml")],
                          env=env, capture_output=True, text=True, timeout=timeout)


with tempfile.TemporaryDirectory(prefix="isla-services-audit-") as td:
    root = Path(td) / "wifi"
    root.mkdir()
    env = environment(root)
    env["AUDIT_NMCLI_LOG"] = str(root / "nmcli.log")
    write(root / "bin/nmcli", '''#!/usr/bin/python3
import os, sys, time
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["AUDIT_NMCLI_LOG"], "a") as log:
    log.write(" ".join(args) + "\\n")
if args == ["monitor"]: time.sleep(3)
elif args == ["connection", "show", "Casa"]: sys.exit(0)
elif args == ["connection", "delete", "Casa"]: sys.exit(0)
elif args[:2] == ["connection", "add"]:
    print("simulated add failure", file=sys.stderr)
    sys.exit(10)
elif args[:3] == ["device", "wifi", "connect"]:
    print("simulated connection failure", file=sys.stderr)
    sys.exit(1)
else: sys.exit(1)
''', True)
    result = shell(root, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    Timer { interval: 200; running: true; onTriggered: Nmcli.connectWithPassword(
        {ssid: "Casa", bssid: "AA:BB:CC:DD:EE:FF"}, "incorrecta", function(result) {
            console.log("AUDIT_WIFI_CALLBACK success=" + result.success)
        }) }
    Timer { interval: 1800; running: true; onTriggered: Qt.quit() }
}
''', env)
    calls = (root / "nmcli.log").read_text().splitlines()
    relevant = [line for line in calls if line.startswith(("connection show Casa", "connection delete Casa", "connection add ", "device wifi connect Casa"))]
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert len(relevant) >= 4 and relevant[0] == "connection show Casa" and relevant[1] == "connection delete Casa" and relevant[2].startswith("connection add ") and relevant[3].startswith("device wifi connect Casa"), relevant
    assert "AUDIT_WIFI_CALLBACK success=false" in result.stderr + result.stdout, (result.stderr, result.stdout)
    print("SVC-01 PASS: fake nmcli order show → delete → add(fail) → fallback(fail); callback false")
    print("SVC-01 calls:", " | ".join(relevant))

    root = Path(td) / "session"
    root.mkdir()
    env = environment(root)
    marker = root / "invoked"
    env["AUDIT_LOCK_MARKER"] = str(marker)
    env["AUDIT_SHELL_LOG"] = str(root / "shell.log")
    write(root / "bin/sh", '''#!/bin/sh
printf '%s\\n' "$*" >> "$AUDIT_SHELL_LOG"
exec /usr/bin/sh "$@"
''', True)
    launcher = root / "xdg-data/quickshell-lockscreen/lock.sh"
    write(launcher, '#!/bin/sh\nprintf invoked > "$AUDIT_LOCK_MARKER"\n', True)
    result = shell(root, '''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    Timer { interval: 100; running: true; onTriggered: { Session.lock(); console.log("AUDIT_SESSION_CALLED") } }
    Timer { interval: 900; running: true; onTriggered: Qt.quit() }
}
''', env)
    assert result.returncode == 0 and "AUDIT_SESSION_CALLED" in result.stderr + result.stdout, (result.stdout, result.stderr)
    assert launcher.exists() and not marker.exists(), "XDG launcher unexpectedly invoked"
    assert not (root / "home/.local/share/quickshell-lockscreen/lock.sh").exists()
    command = (root / "shell.log").read_text().strip()
    assert command == "-c ~/.local/share/quickshell-lockscreen/lock.sh", command
    print("SVC-02 PASS: Session.lock() invoked", command, "; XDG launcher exists but was not invoked; fixed HOME path absent")

    root = Path(td) / "clipboard"
    root.mkdir()
    env = environment(root)
    png = root / "image.png"
    subprocess.run(["magick", "-size", "64x32", "xc:steelblue", str(png)], check=True)
    env["AUDIT_CLIP_IMAGE"] = str(png)
    write(root / "bin/cliphist", '''#!/bin/sh
case "$1" in
list) printf '2\\t[[ binary data png ]]\\n' ;;
decode) cat "$AUDIT_CLIP_IMAGE" ;;
wipe) exit 0 ;;
esac
''', True)
    copied = root / "bar"
    shutil.copytree(REPO / "bar", copied)
    write(copied / "services-audit.qml", '''import QtQuick
import Quickshell
import "surfaces"
ShellRoot {
    Window {
        visible: true; width: 620; height: 540
        ClipboardSurface { id: surface; anchors.fill: parent; open: true }
        Timer { interval: 1200; running: true; onTriggered: surface.clearHistory() }
        Timer { interval: 2600; running: true; onTriggered: {
            console.log("AUDIT_CLEAR entries=" + surface.entries.length + " clearing=" + surface.clearing)
        } }
        Timer { interval: 4700; running: true; onTriggered: Qt.quit() }
    }
}
''')
    proc = subprocess.Popen(["quickshell", "-p", str(copied / "services-audit.qml")], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(3.2)
    previews = list((root / "runtime").glob("isla-clipboard.*/*.png"))
    assert proc.poll() is None, "clipboard fixture exited before inspection"
    stdout, stderr = proc.communicate(timeout=5)
    assert proc.returncode == 0 and "AUDIT_CLEAR entries=0 clearing=false" in stderr + stdout, (stdout, stderr)
    assert previews, "no PNG remained after clear"
    print("SVC-04 PASS: cliphist wipe completed (entries=0), PNG remained while surface alive:", [p.name for p in previews])

    root = Path(td) / "power"
    root.mkdir()
    env = environment(root)
    env["AUDIT_POWER_LOG"] = str(root / "power.log")
    write(root / "bin/powerprofilesctl", '''#!/bin/sh
printf '%s\\n' "$*" >> "$AUDIT_POWER_LOG"
case "$1" in
get) printf 'balanced\\n'; exit 0 ;;
set) exit 1 ;;
esac
exit 2
''', True)
    result = shell(root, '''import QtQuick
import QtTest
import Quickshell
import "components"
ShellRoot {
    Window {
        id: scene
        visible: true; width: 620; height: 540
        QuickControlsAdapter { id: adapter; anchors.fill: parent; contentReady: true }
        Timer { interval: 60; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ServicePowerProfileAudit"
            when: scene.visible
            property bool finished: false
            function test_real_control_failed_command() {
                wait(500)
                const control = findChild(adapter, "profile-performance")
                verify(control !== null, "real profile control exists")
                mouseClick(control, control.width / 2, control.height / 2)
                wait(350)
                const summary = findChild(adapter, "powerProfileSummary")
                console.log("AUDIT_POWER_UI active=" + adapter.activeProfile + " summary=" + summary.text)
                finished = true
            }
        }
    }
}
''', env)
    actual = subprocess.run([str(root / "bin/powerprofilesctl"), "get"], env=env,
                            capture_output=True, text=True, check=True)
    calls = (root / "power.log").read_text().splitlines()
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert calls == ["get", "set performance", "get"] and actual.stdout.strip() == "balanced", (calls, actual.stdout)
    assert "AUDIT_POWER_UI active=performance summary=Máximo rendimiento · más consumo" in result.stderr + result.stdout, (result.stdout, result.stderr)
    print("SVC-05 PASS: real QtTest click selected performance, fake set failed, service get remained balanced; calls:", " | ".join(calls))

print("All reproductions used temporary HOME/XDG/PATH, fake nmcli/cliphist/powerprofilesctl, and an offscreen Quickshell copy.")
