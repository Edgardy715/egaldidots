#!/usr/bin/env python3
"""Backend selection, exact argv/ownership and optional atomic installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="isla backend ") as directory:
    temp = Path(directory)
    services = temp / "services"
    services.mkdir()
    launcher = services / "cava-stream.sh"
    launcher.write_bytes((ROOT / "bar/services/cava-stream.sh").read_bytes())
    recorder = "import json,os,sys; print(json.dumps([os.getppid(),sys.argv[1:]]))\n"
    (services / "cava_stream.py").write_text(recorder)
    data = temp / "data with spaces"
    env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CACHE_HOME=str(temp / "cache"))
    arguments = ["--identity", "player ' ; $()", "--desktop", "", "--bus", "org.mpris.test"]
    command = ["sh", str(launcher), str(os.getpid()), *arguments]
    assert json.loads(subprocess.check_output(command, env=env)) == [os.getpid(), arguments]
    native = data / "isla/bin/isla-cava-stream"
    native.parent.mkdir(parents=True)
    native.write_text("#!/usr/bin/python3\n" + recorder)
    native.chmod(0o755)
    assert json.loads(subprocess.check_output(command, env=env)) == [
        os.getpid(), ["--parent", str(os.getpid()), *arguments]]
    fake_bin = temp / "bin"
    fake_bin.mkdir()
    cargo = fake_bin / "cargo"
    cargo.write_text("#!/bin/sh\nset -eu\n[ \"$1\" = build ]\n"
                     "mkdir -p \"$CARGO_TARGET_DIR/release\"\n"
                     "printf '#!/bin/sh\\nexit 0\\n' > \"$CARGO_TARGET_DIR/release/isla-cava-stream\"\n")
    cargo.chmod(0o755)
    env["PATH"] = str(fake_bin) + os.pathsep + env["PATH"]
    subprocess.run(["sh", str(ROOT / "scripts/build-cava-helper.sh")], env=env, check=True)
    assert native.read_text() == "#!/bin/sh\nexit 0\n" and os.access(native, os.X_OK)
    assert not list(native.parent.glob(".cava-stream.*"))
    cargo.write_text("#!/bin/sh\nexit 17\n")
    assert subprocess.run(["sh", str(ROOT / "scripts/build-cava-helper.sh")], env=env).returncode == 17
    assert native.read_text() == "#!/bin/sh\nexit 0\n"

    # Exercise the real QML Process caller without opening an audio capture.
    bar = temp / "bar"
    shutil.copytree(ROOT / "bar", bar)
    source = bar / "Singletons/Cava.qml"
    source.write_text(source.read_text().replace("Component.onCompleted: probe.running = true",
                                                "Component.onCompleted: {}"))
    marker = temp / "owner.json"
    fake = ("import json,os,sys,time\n"
            f"open({str(marker)!r},'w').write(json.dumps([os.getpid(),os.getppid(),sys.argv[1:]]))\n"
            "while True:\n print(' '.join(['1000']*24),flush=True); time.sleep(0.016)\n")
    (bar / "services/cava_stream.py").write_text(fake)
    fixture = bar / "backend-regression.qml"
    fixture.write_text('''import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window { visible: true; width: 100; height: 50 }
    Component.onCompleted: { Cava.available = true; Cava.setConsumer("test", true) }
    Timer {
        running: true; interval: 800
        onTriggered: {
            if (!Cava.hasFrame || !Cava.values.some(v => v > 0)) {
                console.error("FAIL: backend frame"); Qt.exit(1); return
            }
            Cava.setConsumer("test", false)
            console.log("PASS: backend frames through real QML Process", Quickshell.processId)
            Qt.quit()
        }
    }
}
''')
    config = temp / "config.json"
    config.write_text("{}")
    env.update(ISLA_CONFIG=str(config), QT_QPA_PLATFORM="offscreen", XDG_STATE_HOME=str(temp / "state"))
    for backend in ("python", "rust"):
        if backend == "python":
            native.unlink()
        else:
            native.write_text("#!/usr/bin/python3\n" + fake)
            native.chmod(0o755)
        process = subprocess.Popen(["qs", "-p", str(fixture)], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output, _ = process.communicate(timeout=10)
        assert process.returncode == 0 and "PASS: backend frames" in output, output
        pid, parent, argv = json.loads(marker.read_text())
        assert parent == process.pid, (backend, parent, process.pid)
        if backend == "rust":
            assert argv[:2] == ["--parent", str(process.pid)], argv
        assert not Path(f"/proc/{pid}").exists(), (backend, pid)
        print(f"PASS: QML {backend} frames, direct owner and consumer cleanup")
    installed = Path(os.environ.get("ISLA_CAVA_RUST_BINARY",
                     Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "isla/bin/isla-cava-stream"))
    if installed.is_file():
        native.unlink()
        shutil.copy2(installed, native)
        text = source.read_text()
        for name in ("Identity", "Desktop", "Bus"):
            start = f"    readonly property string player{name}:"
            text = "\n".join(start + ' "isla-backend-unresolved-fixture"' if line.startswith(start)
                             else line for line in text.splitlines()) + "\n"
        source.write_text(text)
        fixture.write_text(fixture.read_text().replace(
            "!Cava.hasFrame || !Cava.values.some(v => v > 0)",
            "!Cava.hasFrame || Cava.values.some(v => v > 0)"))
        result = subprocess.run(["qs", "-p", str(fixture)], env=env, capture_output=True,
                                text=True, timeout=10)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "PASS: backend frames" in output, output
        print("PASS: installed Rust through QML, unresolved identity remains silent")
print("PASS: Python fallback, native selection, exact argv, direct ownership, atomic install/failure")
