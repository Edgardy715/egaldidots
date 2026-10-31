"""Native desktop journeys with a disposable app; no user windows/config modified."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parents[1]
evidence = source.parent / "docs/desktop-integration-2026-10-26"


def run(*args, env=None):
    return subprocess.run(args, env=env, capture_output=True, text=True, check=True, timeout=5).stdout.strip()


def wait_for(read, predicate, label, timeout=7):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            last = read()
            if predicate(last):
                return last
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            pass
        time.sleep(.05)
    raise AssertionError(f"{label}: {last}")


original = json.loads(run("hyprctl", "activewindow", "-j")).get("address")
with tempfile.TemporaryDirectory(prefix="isla-desktop-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    auth = root / "bar/Singletons/Auth.qml"
    auth_source = auth.read_text()
    socket_expression = 'Quickshell.env("XDG_RUNTIME_DIR")\n        + "/isla-sudo-askpass.sock"'
    assert socket_expression in auth_source, "Auth socket isolation needs updating"
    auth.write_text(auth_source.replace(socket_expression, json.dumps(str(root / "askpass.sock"))))
    fixture = root / "bar/overlay-native-input-regression.qml"
    config = root / "shell.json"
    config.write_text('{"appearance":{"reduceMotion":true}}')
    peer = root / "probe.qml"
    peer.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        title: "Isla Desktop Probe"
        visible: true; width: 520; height: 320
        color: "#252936"
        TextInput { id: input; anchors.fill: parent; color: "white"; focus: true; font.pixelSize: 24 }
    }
    IpcHandler {
        target: "probe"
        function text(): string { return input.text }
        function clear(): void { input.text = "" }
    }
}''')
    apps = root / "data/applications"
    apps.mkdir(parents=True)
    (apps / "isla-desktop-probe.desktop").write_text(
        f'[Desktop Entry]\nType=Application\nName=IslaDesktopProbe\nExec=qs -p "{peer}"\nTerminal=false\n')
    env = dict(os.environ, QT_QPA_PLATFORM="wayland", ISLA_CONFIG=str(config),
               XDG_STATE_HOME=str(root / "state"), XDG_DATA_HOME=str(root / "data"))
    peer_log = (root / "probe.log").open("w+")
    overlay_log = (root / "overlay.log").open("w+")
    process = None
    probe_process = subprocess.Popen(["qs", "-p", str(peer)], env=env, stdout=peer_log, stderr=subprocess.STDOUT)

    def ipc(path, target, method, *args):
        return run("qs", "-p", str(path), "ipc", "call", target, method, *args, env=env)

    def call(method, *args):
        return ipc(fixture, "nativeInputTest", method, *args)

    def state():
        return json.loads(call("state"))

    def surface(name):
        return wait_for(state, lambda value: value["surface"] == name and value["wantsKeyboard"] == bool(name), "surface " + repr(name))

    def key(*args):
        run("wtype", *args, env=env)

    def probe_address():
        windows = json.loads(run("hyprctl", "clients", "-j"))
        return next((w["address"] for w in windows if w["title"] == "Isla Desktop Probe"), "")

    def focus(address):
        run("hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{address}" }})')

    def typed(text):
        ipc(peer, "probe", "clear")
        key(text)
        wait_for(lambda: ipc(peer, "probe", "text"), lambda value: value == text, "app receives keyboard " + text)

    address = ""
    try:
        address = wait_for(probe_address, bool, "probe mapped")
        focus(address)
        process = subprocess.Popen(["qs", "-p", str(fixture)], env=env, stdout=overlay_log, stderr=subprocess.STDOUT)
        surface("")
        typed("initial")
        for name in ["calendar", "mixer", "connectivity", "workspaces", "notifs", "utils", "appearance",
                     "launcher", "media", "wallpaper", "clipboard", "overview", "session", "settings"]:
            call("open", name)
            surface(name)
            time.sleep(.18)
            key("-k", "Escape")
            surface("")
            typed(name)
            print("PASS native Escape restores typing:", name, flush=True)
        call("open", "settings")
        surface("settings")
        time.sleep(.3)
        call("settingsSearch")
        key("motion")
        wait_for(state, lambda value: value["search"] == "motion", "settings search typed")
        key("-k", "Escape")
        wait_for(state, lambda value: value["search"] == "" and value["surface"] == "settings", "Escape clears search first")
        key("-k", "Escape")
        surface("")
        typed("nested")
        print("PASS native settings Escape clears search before closing panel", flush=True)
        call("open", "workspaces")
        surface("workspaces")
        time.sleep(.25)
        call("selectWorkspace")
        surface("")
        typed("workspace")
        print("PASS workspace confirmation returns keyboard to app", flush=True)
        # Fullscreen only our disposable app; test requests arriving after fullscreen too.
        run("hyprctl", "dispatch", f'hl.dsp.window.fullscreen({{ window = "address:{address}", action = "set" }})')
        wait_for(state, lambda value: value["fullscreen"], "actual compositor fullscreen")
        for name in ["calendar", "launcher", "overview", "auth"]:
            call("open", name)
            wait_for(state, lambda value: not value["surface"] and not value["pending"] and not value["wantsKeyboard"], "fullscreen rejects " + name)
            typed("fullscreen" + name)
        run("hyprctl", "dispatch", f'hl.dsp.window.fullscreen({{ window = "address:{address}", action = "unset" }})')
        wait_for(state, lambda value: not value["fullscreen"] and not value["surface"], "fullscreen leaves no stale panel")
        print("PASS actual fullscreen rejects panels/docks/auth without capturing keyboard", flush=True)
        # Use the real DesktopEntry.execute path; test both animated and immediate closure.
        for reduced in [False, True]:
            probe_process.terminate()
            probe_process.wait(timeout=5)
            wait_for(probe_address, lambda value: not value, "previous probe unmapped")
            call("motion", str(reduced).lower())
            wait_for(state, lambda value: value["reduced"] == reduced and value["routerReduced"] == reduced, "motion configuration")
            call("open", "launcher")
            surface("launcher")
            key("IslaDesktopProbe")
            wait_for(state, lambda value: value["query"] == "IslaDesktopProbe" and value["results"] == 1 and not value["searching"], "launcher app result")
            key("-k", "Return")
            wait_for(lambda: {"address": probe_address(), "overlay": state()}, lambda value: bool(value["address"]), "launched probe")
            surface("")
            typed("launched")
            # Include time beyond any delayed focus request by the closing overlay.
            time.sleep(.8)
            typed("stillfocused")
            print("PASS native launcher executes app and transfers focus, reducedMotion=" + str(reduced), flush=True)
            # DesktopEntry-spawned process is owned by qs; shut down by exact temp config.
            run("qs", "-p", str(peer), "kill", env=env)
            wait_for(probe_address, lambda value: not value, "launched probe unmapped")
            if not reduced:
                probe_process = subprocess.Popen(["qs", "-p", str(peer)], env=env, stdout=peer_log, stderr=subprocess.STDOUT)
                address = wait_for(probe_address, bool, "probe relaunched")
        print("PASS: desktop integration native journeys", flush=True)
    finally:
        if address and probe_address():
            subprocess.run(["hyprctl", "dispatch", f'hl.dsp.window.fullscreen({{ window = "address:{address}", action = "unset" }})'], capture_output=True)
        if process:
            process.terminate()
            process.wait(timeout=5)
        subprocess.run(["qs", "-p", str(peer), "kill"], env=env, capture_output=True)
        if probe_process.poll() is None:
            probe_process.terminate()
        probe_process.wait(timeout=5)
        runtime_errors = []
        for name, log in [("native-overlay.log", overlay_log), ("native-probe.log", peer_log)]:
            log.flush()
            log.seek(0)
            output = log.read()
            evidence.mkdir(parents=True, exist_ok=True)
            (evidence / name).write_text(output)
            if any(word in output for word in ["FAIL", "TypeError", "ReferenceError", "Binding loop"]):
                runtime_errors.append(name)
            log.close()
        if original and any(w["address"] == original for w in json.loads(run("hyprctl", "clients", "-j"))):
            focus(original)
        assert not runtime_errors, "QML runtime errors; inspect " + ", ".join(runtime_errors)
