#!/usr/bin/env python3
"""Exercise the Hyprland bridge with a fake hyprctl and isolated settings."""
import json
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from unittest.mock import patch


BAR = Path(__file__).resolve().parents[1]
HELPER = BAR / "scripts/hyprland-settings.py"
FAKE = '''#!/usr/bin/env python3
import json, os, re, sys
from pathlib import Path
p = Path(os.environ["FAKE_STATE"])
s = json.loads(p.read_text())
a = sys.argv[1:]
if a[:3] == ["-j", "getoption", "general:layout"]: print(json.dumps({"str":s["layout"]}))
elif a[:3] == ["-j", "getoption", "animations:enabled"]: print('{"bool":true}')
elif a == ["-j", "animations"]:
    if s.pop("failRead", False): p.write_text(json.dumps(s)); sys.exit(1)
    s["animReads"] = s.get("animReads", 0) + 1
    if os.environ.get("FAKE_EXTERNAL_CURVE_ON_THIRD_READ") and s["animReads"] == 3:
        s["leaves"]["windowsIn"]["bezier"] = "externalAfterInit"
    p.write_text(json.dumps(s))
    print(json.dumps([list(s["leaves"].values()), []]))
elif a == ["-j", "version"]: print('{"version":"0.56.2"}')
elif a[0] == "eval":
    code = a[1]
    if "reload" in code or os.environ.get("FAKE_FAIL") == "1" and "windowsOut" in code:
        print("rejected"); sys.exit(1)
    if code.startswith("hl.config"):
        s["layout"] = re.search(r'layout = "([^"]+)"', code).group(1)
    else:
        name = re.search(r'leaf = "([^"]+)"', code).group(1)
        leaf = s["leaves"][name]
        leaf["overridden"] = True
        leaf["enabled"] = "enabled = true" in code
        if leaf["enabled"]:
            leaf["speed"] = float(re.search(r'speed = ([0-9.]+)', code).group(1))
            leaf["style"] = re.search(r'style = "([^"]*)"', code).group(1)
            curve = re.search(r'(bezier|spring) = "([^"]+)"', code)
            leaf["bezier"] = ("spring:" if curve.group(1) == "spring" else "") + curve.group(2)
        else:
            leaf.update(speed=0, style="", bezier="")
    if os.environ.get("FAKE_FAIL_READ_AFTER_EVAL") and not s.get("failedRead"):
        s["failRead"] = True; s["failedRead"] = True
    p.write_text(json.dumps(s)); print("ok")
else: sys.exit(2)
'''


def leaf(name, *, inherited=False):
    return {"name": name, "overridden": not inherited, "enabled": True,
            "speed": 2.6, "style": "slide" if name == "workspaces" else "popin 94%", "bezier": "serpantinum"}


with tempfile.TemporaryDirectory(prefix="isla-hypr-test-") as directory:
    folder = Path(directory)
    fake = folder / "hyprctl"
    fake.write_text(FAKE)
    fake.chmod(0o755)
    state = folder / "runtime.json"
    state.write_text(json.dumps({"layout": "scrolling", "leaves": {name: leaf(name) for name in
                                 ("global", "windows", "windowsIn", "windowsOut", "workspaces")}}))
    config = folder / "nested/hyprland.json"
    env = dict(os.environ, ISLA_HYPRCTL=str(fake), FAKE_STATE=str(state), ISLA_HYPRLAND_CONFIG=str(config))

    def call(action, *args, good=True, environment=env):
        result = subprocess.run(["python3", str(HELPER), action, *map(json.dumps, args)],
                                env=environment, capture_output=True, text=True, timeout=5)
        body = json.loads(result.stdout)
        assert (result.returncode == 0) == good, (action, body, result.stderr)
        return body

    started = call("initialize")
    assert started["runtime"]["values"]["layout"] == "scrolling" and not config.exists()
    target = json.loads(json.dumps(started["saved"]))
    target["layout"] = "master"
    target["windowsIn"]["speed"] = 4.2
    target["windowsIn"]["style"] = "popin 87%"
    target["windowsOut"]["enabled"] = False
    changed = call("apply", target, started["runtime"])["runtime"]
    assert changed["values"]["windowsIn"]["speed"] == 4.2
    assert changed["raw"]["windowsIn"]["bezier"] == "serpantinum"
    assert changed["layout"] == "master" and not config.exists()
    curves = {name: "serpantinum" for name in ("windowsIn", "windowsOut", "workspaces")}
    digest = call("save", target, None, curves)["digest"]
    assert json.loads(config.read_text())["values"] == target
    assert call("save", target, None, curves, good=False)["error"].startswith("Settings changed")
    assert call("save", target, digest, curves)["digest"] == digest
    module_spec = importlib.util.spec_from_file_location("hypr_bridge", HELPER)
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    module.FILE = config
    original_bytes = config.read_bytes()
    with patch.object(module.os, "replace", side_effect=OSError("simulated rename failure")):
        try:
            module.save(target, digest, curves)
            raise AssertionError("rename failure must propagate")
        except OSError:
            pass
    assert config.read_bytes() == original_bytes
    assert not list(config.parent.glob(".hyprland-*"))
    restored = call("apply", started["saved"], started["runtime"])["runtime"]
    assert restored["values"] == started["saved"] and restored["raw"]["windowsIn"]["bezier"] == "serpantinum"
    restarted = call("initialize")
    assert restarted["runtime"]["values"]["layout"] == "master"
    assert restarted["baseline"]["raw"]["windowsOut"]["bezier"] == "serpantinum"
    failing = json.loads(json.dumps(target))
    failing["windowsOut"]["enabled"] = True
    assert not call("apply", failing, restarted["baseline"], good=False,
                    environment=dict(env, FAKE_FAIL="1"))["ok"]
    readback_target = json.loads(json.dumps(target))
    readback_target["layout"] = "dwindle"
    assert not call("apply", readback_target, restarted["baseline"], good=False,
                    environment=dict(env, FAKE_FAIL_READ_AFTER_EVAL="1"))["ok"]
    assert json.loads(state.read_text())["layout"] == "master"
    external = json.loads(state.read_text())
    external["leaves"]["windowsIn"]["bezier"] = "externalCurve"
    state.write_text(json.dumps(external))
    changed_speed = json.loads(json.dumps(target))
    changed_speed["windowsIn"]["speed"] = 4.5
    live_curve = call("apply", changed_speed, restarted["baseline"])["runtime"]
    assert live_curve["raw"]["windowsIn"]["bezier"] == "externalCurve"
    previous_state, previous_file = state.read_text(), config.read_bytes()
    config.unlink()
    disabled = json.loads(previous_state)
    disabled["leaves"]["windowsIn"].update(enabled=False, speed=0, style="", bezier="")
    state.write_text(json.dumps(disabled))
    disabled_start = call("initialize")
    assert disabled_start["runtime"]["values"]["windowsIn"]["speed"] == 2.6
    assert disabled_start["baseline"]["raw"]["windowsIn"]["bezier"] == "serpantinum"
    state.write_text(previous_state)
    config.write_bytes(previous_file)
    hostdir = folder / "qml"
    (hostdir / "Singletons").mkdir(parents=True)
    (hostdir / "scripts").mkdir()
    shutil.copy(BAR / "Singletons/HyprlandSettings.qml", hostdir / "Singletons/HyprlandSettings.qml")
    shutil.copy(HELPER, hostdir / "scripts/hyprland-settings.py")
    (hostdir / "Singletons/qmldir").write_text("singleton HyprlandSettings HyprlandSettings.qml\n")
    (hostdir / "host.qml").write_text('''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    id: host
    property int stage: 0
    Component.onCompleted: HyprlandSettings.initialize()
    Timer { interval: 6000; running: true; onTriggered: { console.log("TIMEOUT", HyprlandSettings.error, host.stage); Qt.exit(2) } }
    Timer {
        interval: 15; repeat: true; running: true
        onTriggered: {
            const service = HyprlandSettings
            if (service.error) { console.log("ERROR", service.error); Qt.exit(3); return }
            if (host.stage === 0 && service.available) {
                service.update({windowsIn: {speed: 4.3}})
                service.update({windowsIn: {speed: 4.4}})
                service.update({layout: "dwindle"})
                service.save()
                host.stage = 1
            } else if (host.stage === 1 && !service.busy && !service.dirty && service.feedback) {
                if (service.values.windowsIn.speed !== 4.4) { Qt.exit(4); return }
                service.update({windowsIn: {speed: 5}})
                host.stage = 2
            } else if (host.stage === 2 && service.busy) {
                service.discard()
                host.stage = 3
            } else if (host.stage === 3 && !service.busy && !service.dirty) {
                if (service.values.windowsIn.speed !== 4.4) { Qt.exit(5); return }
                console.log("PASS: QML Hyprland service serializes rapid updates and discard")
                Qt.quit()
            }
        }
    }
}
''')
    qml_env = dict(env, QT_QPA_PLATFORM="offscreen")
    qml = subprocess.run(["quickshell", "-p", str(hostdir / "host.qml")], env=qml_env,
                         capture_output=True, text=True, timeout=10)
    assert qml.returncode == 0 and "PASS: QML Hyprland service" in qml.stdout + qml.stderr, qml.stdout + qml.stderr
    assert json.loads(state.read_text())["leaves"]["windowsIn"]["speed"] == 4.4, (state.read_text(), qml.stdout, qml.stderr)
    assert json.loads(config.read_text())["values"]["layout"] == "dwindle"
    assert json.loads(config.read_text())["curves"]["windowsIn"] == "externalCurve"
    before_disable = json.loads(state.read_text())
    before_disable["leaves"]["windowsIn"]["bezier"] = "serpantinum"
    before_disable["animReads"] = 0
    state.write_text(json.dumps(before_disable))
    saved_before_disable = json.loads(config.read_text())
    saved_before_disable["curves"]["windowsIn"] = "serpantinum"
    config.write_text(json.dumps(saved_before_disable))
    (hostdir / "host.qml").write_text('''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    id: host
    property int stage: 0
    Component.onCompleted: HyprlandSettings.initialize()
    Timer { interval: 6000; running: true; onTriggered: { console.log("TIMEOUT", HyprlandSettings.error); Qt.exit(2) } }
    Timer {
        interval: 15; repeat: true; running: true
        onTriggered: {
            const service = HyprlandSettings
            if (service.error) { console.log("ERROR", service.error); Qt.exit(3); return }
            if (host.stage === 0 && service.available) {
                service.update({windowsIn: {enabled: false}})
                service.save()
                host.stage = 1
            } else if (host.stage === 1 && !service.busy && !service.dirty && service.feedback) {
                console.log("PASS: QML retained external curve before disable")
                Qt.quit()
            }
        }
    }
}
''')
    disable_qml = subprocess.run(["quickshell", "-p", str(hostdir / "host.qml")],
                                 env=dict(qml_env, FAKE_EXTERNAL_CURVE_ON_THIRD_READ="1"),
                                 capture_output=True, text=True, timeout=10)
    assert disable_qml.returncode == 0 and "PASS: QML retained" in disable_qml.stdout + disable_qml.stderr, disable_qml.stdout + disable_qml.stderr
    assert json.loads(state.read_text())["leaves"]["windowsIn"]["bezier"] == ""
    assert json.loads(config.read_text())["curves"]["windowsIn"] == "externalAfterInit"
    disabled_restart = call("initialize")
    assert disabled_restart["baseline"]["raw"]["windowsIn"]["bezier"] == "externalAfterInit"
    enabled_again = json.loads(json.dumps(disabled_restart["saved"]))
    enabled_again["windowsIn"]["enabled"] = True
    reenabled = call("apply", enabled_again, disabled_restart["baseline"])["runtime"]
    assert reenabled["raw"]["windowsIn"]["bezier"] == "externalAfterInit"
    hostile = json.loads(json.dumps(target))
    hostile["windowsIn"]["style"] = 'popin 94%" }); os.execute("bad")'
    assert not call("apply", hostile, started["runtime"], good=False)["ok"]
    assert json.loads(state.read_text())["layout"] == "dwindle"
    inherited = json.loads(state.read_text())
    inherited["leaves"]["windowsIn"]["overridden"] = False
    state.write_text(json.dumps(inherited))
    current = call("refresh")["runtime"]
    target2 = json.loads(json.dumps(current["values"]))
    target2["windowsIn"]["speed"] = 5
    assert "inherited" in call("apply", target2, current, good=False)["error"]
    assert json.loads(state.read_text())["leaves"]["windowsIn"]["overridden"] is False
    config.write_text("{ bad")
    before_recovery = json.loads(state.read_text())
    invalid = call("initialize")
    assert invalid["persistenceError"] and invalid["runtime"]["values"]["layout"] == "dwindle"
    assert json.loads(state.read_text())["leaves"] == before_recovery["leaves"] and config.read_text() == "{ bad"
    assert not call("reset", invalid["runtime"]["values"], "wrong digest", curves, good=False)["ok"]
    assert config.read_text() == "{ bad"
    recovered = call("reset", invalid["runtime"]["values"], invalid["digest"], curves)
    assert Path(recovered["backup"]).read_text() == "{ bad"
    assert json.loads(config.read_text())["values"]["layout"] == "dwindle"
    assert json.loads(state.read_text())["leaves"] == before_recovery["leaves"]
    assert not call("refresh")["persistenceError"]
    print("PASS: isolated preview, QML serialization, inherited leaves, rollback, invalid-file recovery, atomic save and conflict")
