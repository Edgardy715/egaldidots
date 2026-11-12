"""Native Wayland captures of bar/iris-continuity-regression.qml on the current desktop."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

out = Path(__file__).resolve().parent
root = out.parents[1]


def window_geometry():
    clients = json.loads(subprocess.run(["hyprctl", "-j", "clients"], check=True, capture_output=True, text=True).stdout)
    for client in clients:
        if "continuidad" in client.get("title", ""):
            x, y = client["at"]
            w, h = client["size"]
            return f"{x},{y} {w}x{h}"
    return None


with tempfile.TemporaryDirectory(prefix="isla-continuity-") as tmp:
    Path(tmp, "iris").mkdir()
    env = dict(os.environ, ISLA_CONFIG=tmp + "/config.json", ISLA_IRIS=tmp + "/iris/iris.json",
               ISLA_TEST_OUTPUT="1", QT_QPA_PLATFORM="wayland")
    process = subprocess.Popen(["timeout", "90s", "quickshell", "-p", "bar/iris-continuity-regression.qml"], cwd=root,
                               env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    for line in process.stdout:
        lines.append(line)
        if "CONTINUITY_CAPTURE " in line:
            name = line.split("CONTINUITY_CAPTURE ")[1].strip()
            path = out / (name + ".png")
            geometry = window_geometry()
            cmd = ["grim"] + (["-g", geometry] if geometry else []) + [str(path)]
            subprocess.run(cmd, check=True)
            subprocess.run(["magick", str(path), "-crop", "1100x140+0+0", "+repage", str(path)], check=True)
            print("capture", name, geometry, flush=True)
    code = process.wait()
    log = "".join(lines)
    (out / "wayland-result.txt").write_text(log)
    print(log[-3000:])
    raise SystemExit(0 if code == 0 and "FAIL:" not in log else 1)
