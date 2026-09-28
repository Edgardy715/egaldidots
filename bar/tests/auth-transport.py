#!/usr/bin/env python3
"""Exercise the real Auth socket through reloads, with fake Polkit and responses."""
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parents[1] / "Singletons/Auth.qml"
text = source.read_text().replace('import Quickshell.Services.Polkit\n', '')
start = text.index('    PolkitAgent {')
end = text.index('\n    Connections {', start)
text = text[:start] + '''    QtObject {
        id: agent
        property bool isRegistered: false
        property bool isActive: false
        property QtObject flow: null
        signal authenticationRequestStarted()
    }
''' + text[end:]
assert 'PolkitAgent {' not in text
reload_function = re.search(r'function reload\(\): bool \{[^}]+\}',
                            (source.parents[1] / "shell.qml").read_text()).group()

with tempfile.TemporaryDirectory(prefix="isla-auth-transport-") as directory:
    root = Path(directory)
    backend = root / "backend"
    backend.mkdir()
    (backend / "Auth.qml").write_text(text)
    (backend / "qmldir").write_text("singleton Auth Auth.qml\n")
    (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "backend"
ShellRoot {
    property bool presenting: Auth.presenting
    IpcHandler {
        target: "fixture"
        @RELOAD_FUNCTION@
        function respond(): bool { return Auth.submitSudo("fixture-response") }
        function cancel(): void { Auth.cancelSudo() }
    }
}
'''.replace("@RELOAD_FUNCTION@", reload_function))
    # Isolated runtime prevents this test from touching the desktop askpass socket.
    display = os.environ.get("WAYLAND_DISPLAY", "wayland-1")
    if not display.startswith("/"):
        display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="wayland",
               WAYLAND_DISPLAY=display)
    socket_path = str(root / "isla-sudo-askpass.sock")
    with (root / "output.log").open("w+") as log:
        process = subprocess.Popen(["quickshell", "-p", directory], env=env,
                                   stdout=log, stderr=subprocess.STDOUT)
        def call(target, method):
            return subprocess.run(["quickshell", "-p", directory, "ipc", "call", target, method],
                                  env=env, capture_output=True, text=True, timeout=5)

        try:
            deadline = time.monotonic() + 8
            while not Path(socket_path).exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise AssertionError("fixture did not open its isolated socket")
                time.sleep(.05)
            for iteration in range(5):
                if iteration:
                    result = call("fixture", "reload")
                    assert result.returncode == 0 and result.stdout.strip() == "true", result.stderr
                    # Wait beyond generation destruction: mere listener existence
                    # during the swap would miss deletion of the replacement path.
                    time.sleep(.3)
                with socket.socket(socket.AF_UNIX) as client:
                    client.settimeout(3)
                    client.connect(socket_path)
                    client.sendall(b'{"id":"fixture","tracked":false,"prompt":"Fixture"}\n')
                    deadline = time.monotonic() + 3
                    status = call("authDebug", "status")
                    while "sudo=true" not in status.stdout:
                        assert time.monotonic() < deadline, ("request did not reach Auth", status.stdout, status.stderr)
                        time.sleep(.02)
                        status = call("authDebug", "status")
                    response = call("fixture", "respond")
                    assert response.stdout.strip() == "true", response.stderr
                    assert client.recv(4096) == b"fixture-response\n", "askpass response lost"
                assert call("fixture", "cancel").returncode == 0
            print("PASS Auth transport: startup and four reloads deliver askpass responses")
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            process.terminate()
            process.wait(timeout=5)
