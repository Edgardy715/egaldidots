#!/usr/bin/env python3
"""Exercise the real Qt profile control against a fake, mutable power service."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[3]
PLATFORM = os.environ.get("ISLA_TEST_PLATFORM", "offscreen")
WAYLAND = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000"),
                       os.environ.get("WAYLAND_DISPLAY", "wayland-1"))
FIXTURE = '''import QtQuick
import QtTest
import Quickshell
import "components"
ShellRoot {
    Window {
        id: scene
        visible: true; width: 620; height: 540
        color: "#222631"
        QuickControlsAdapter { id: adapter; anchors.fill: parent; contentReady: true }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ServicePowerProfile"
            when: scene.visible
            property bool finished: false
            function test_profile_control() {
                wait(500)
                const control = findChild(adapter, "profile-performance")
                verify(control !== null && control.enabled)
                mouseClick(control, control.width / 2, control.height / 2)
                wait(550)
                const summary = findChild(adapter, "powerProfileSummary")
                const error = findChild(adapter, "powerProfileError")
                console.log("PROFILE_RESULT active=" + adapter.activeProfile + " error=" + error.text
                    + " summary=" + summary.text + " selected=" + control.Accessible.checked)
                const shot = Quickshell.env("AUDIT_POWER_SHOT")
                if (shot.length) {
                    scene.contentItem.grabToImage(function(image) {
                        console.log("PROFILE_SHOT=" + image.saveToFile(shot))
                        finished = true
                    })
                } else finished = true
            }
        }
    }
}
'''


def case(mode):
    with tempfile.TemporaryDirectory(prefix="isla-profile-check-") as td:
        root = Path(td)
        (root / "runtime").mkdir(mode=0o700)
        (root / "home").mkdir()
        (root / "bin").mkdir()
        (root / "state").write_text("balanced\n")
        bar = root / "bar"
        shutil.copytree(REPO / "bar", bar)
        (bar / "services-power-check.qml").write_text(FIXTURE)
        fake = root / "bin/powerprofilesctl"
        fake.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$AUDIT_POWER_LOG"
case "$1" in
get) cat "$AUDIT_POWER_STATE" ;;
set) if [ "$AUDIT_POWER_MODE" = success ]; then printf '%s\\n' "$2" > "$AUDIT_POWER_STATE"; else exit 1; fi ;;
esac
''')
        fake.chmod(0o700)
        env = dict(os.environ, HOME=str(root / "home"), XDG_RUNTIME_DIR=str(root / "runtime"),
                   ISLA_CONFIG=str(root / "config.json"), QT_QPA_PLATFORM=PLATFORM,
                   PATH=str(root / "bin") + os.pathsep + os.environ["PATH"],
                   AUDIT_POWER_LOG=str(root / "power.log"), AUDIT_POWER_STATE=str(root / "state"),
                   AUDIT_POWER_MODE=mode)
        if PLATFORM == "wayland":
            env["WAYLAND_DISPLAY"] = WAYLAND
            if mode == "failed":
                env["AUDIT_POWER_SHOT"] = str(Path(__file__).with_name("services-power-failed.png"))
        result = subprocess.run(["quickshell", "-p", str(bar / "services-power-check.qml")],
                                env=env, capture_output=True, text=True, timeout=6)
        assert result.returncode == 0, (result.stdout, result.stderr)
        trace = result.stdout + result.stderr
        assert "set performance" in (root / "power.log").read_text(), trace
        expected = "performance" if mode == "success" else "balanced"
        assert (root / "state").read_text().strip() == expected, trace
        assert "PROFILE_RESULT active=" + expected in trace, trace
        if mode == "failed":
            assert "error=No se pudo aplicar el perfil." in trace and "selected=false" in trace, trace
        else:
            assert "error= summary=Máximo rendimiento" in trace, trace
        print(f"PASS: {mode} click, actual={expected}, UI={expected}, service calls="
              + " | ".join((root / "power.log").read_text().splitlines()))


case("failed")
case("success")


def external_case(initial, replacement, expected_error):
    with tempfile.TemporaryDirectory(prefix="isla-profile-external-") as td:
        root = Path(td)
        for part in ("runtime", "home", "bin"):
            (root / part).mkdir()
        state = root / "state"
        if initial is not None:
            state.write_text(initial + "\n")
        bar = root / "bar"
        shutil.copytree(REPO / "bar", bar)
        (bar / "services-power-external.qml").write_text('''import QtQuick
import Quickshell
import "components"
ShellRoot {
    Window {
        visible: true; width: 620; height: 540
        QuickControlsAdapter { id: adapter; anchors.fill: parent; contentReady: true }
        Timer { interval: 4800; running: true; onTriggered: {
            console.log("EXTERNAL_RESULT active=" + adapter.activeProfile + " error=" + adapter.profileError)
            Qt.quit()
        } }
    }
}
''')
        fake = root / "bin/powerprofilesctl"
        fake.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$AUDIT_POWER_LOG"
case "$1" in
get) cat "$AUDIT_POWER_STATE" ;;
set) exit 1 ;;
esac
''')
        fake.chmod(0o700)
        env = dict(os.environ, HOME=str(root / "home"), XDG_RUNTIME_DIR=str(root / "runtime"),
                   ISLA_CONFIG=str(root / "config.json"), QT_QPA_PLATFORM=PLATFORM,
                   PATH=str(root / "bin") + os.pathsep + os.environ["PATH"],
                   AUDIT_POWER_LOG=str(root / "power.log"), AUDIT_POWER_STATE=str(state))
        if PLATFORM == "wayland":
            env["WAYLAND_DISPLAY"] = WAYLAND
        proc = subprocess.Popen(["quickshell", "-p", str(bar / "services-power-external.qml")],
                                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        time.sleep(1.4)
        state.write_text(replacement + "\n")
        stdout, stderr = proc.communicate(timeout=7)
        trace = stdout + stderr
        assert proc.returncode == 0 and f"EXTERNAL_RESULT active={replacement} error={expected_error}" in trace, trace
        assert (root / "power.log").read_text().splitlines() == ["get", "get"], trace
        print(f"PASS: external/read-recovery initial={initial}, actual={replacement}, UI={replacement}, error={expected_error!r}")


external_case("balanced", "power-saver", "")
external_case(None, "balanced", "")
