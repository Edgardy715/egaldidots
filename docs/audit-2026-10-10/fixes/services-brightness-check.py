#!/usr/bin/env python3
"""Keyboard/a11y brightness fixture without a real brightness service."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix="isla-brightness-") as td:
    root = Path(td)
    for part in ("home", "runtime"):
        (root / part).mkdir()
    bar = root / "bar"
    shutil.copytree(REPO / "bar", bar)
    (bar / "services-brightness-check.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import "components"
ShellRoot {
    Window {
        id: scene
        visible: true; width: 620; height: 540
        QuickControlsView {
            id: view
            anchors.fill: parent
            contentReady: true
            showBrightness: true
            brightnessPercent: 40
            onBrightnessStepRequested: delta => { stepCount++; stepDelta += delta }
            onBrightnessSetPercent: value => liveCount++
            property int stepCount: 0
            property int stepDelta: 0
            property int liveCount: 0
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "BrightnessKeyboard"
            when: scene.visible
            property bool finished: false
            function test_step() {
                console.log("BRIGHTNESS_TEST_START")
                wait(150)
                const slider = findChild(view, "brightnessSlider")
                console.log("BRIGHTNESS_SLIDER=" + slider + " enabled=" + (slider && slider.enabled))
                verify(slider !== null && slider.enabled)
                verify(slider.activeFocusOnTab)
                compare(slider.Accessible.role, Accessible.Slider)
                slider.forceActiveFocus()
                keyClick(Qt.Key_Tab)
                verify(!slider.activeFocus)
                keyClick(Qt.Key_Tab, Qt.ShiftModifier)
                verify(slider.activeFocus)
                console.log("BRIGHTNESS_KEY=" + Qt.Key_Right + " focus=" + slider.activeFocus)
                keyClick(Qt.Key_Right)
                console.log("BRIGHTNESS_AFTER_KEY step=" + view.stepCount + " live=" + view.liveCount)
                compare(view.stepCount, 1)
                compare(view.stepDelta, 5)
                compare(view.liveCount, 0)
                keyClick(Qt.Key_Left)
                slider.Accessible.increaseAction()
                slider.Accessible.decreaseAction()
                compare(view.stepCount, 4)
                compare(view.stepDelta, 0)
                view.showBrightness = false
                compare(slider.enabled, false)
                keyClick(Qt.Key_Right)
                slider.Accessible.increaseAction()
                slider.Accessible.decreaseAction()
                compare(view.stepCount, 4)
                console.log("BRIGHTNESS_RESULT step=" + view.stepCount + " delta=" + view.stepDelta
                    + " live=" + view.liveCount + " disabled=" + !slider.enabled)
                finished = true
            }
        }
    }
}
''')
    env = dict(os.environ, HOME=str(root / "home"), XDG_RUNTIME_DIR=str(root / "runtime"),
               QT_QPA_PLATFORM="offscreen", ISLA_CONFIG=str(root / "config.json"))
    result = subprocess.run(["quickshell", "-p", str(bar / "services-brightness-check.qml")],
                            env=env, capture_output=True, text=True, timeout=5)
    trace = result.stdout + result.stderr
    assert result.returncode == 0 and "BRIGHTNESS_RESULT step=4 delta=0 live=0 disabled=true" in trace, trace
    print("UI04 PASS: Tab/Shift-Tab, Left/Right, Accessible slider actions; disabled ignores actions; no duplicate live writes")
