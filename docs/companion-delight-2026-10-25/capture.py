"""Capture native Wayland fixture on the current 1920x1080 desktop."""
import os
from pathlib import Path
import subprocess
import tempfile

out = Path(__file__).resolve().parent
root = out.parents[1]
with tempfile.TemporaryDirectory(prefix="isla-delight-") as tmp:
    env = dict(os.environ, ISLA_CONFIG=tmp + "/config.json", ISLA_TEST_OUTPUT="1", QT_QPA_PLATFORM="wayland")
    process = subprocess.Popen(["timeout", "45s", "quickshell", "-p", "bar/companion-delight-regression.qml"], cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    for line in process.stdout:
        lines.append(line)
        if "DELIGHT_CAPTURE " in line:
            name = line.split("DELIGHT_CAPTURE ")[1].strip()
            path = out / (name + ".png")
            subprocess.run(["grim", str(path)], check=True)
            # Keep only the fixture, excluding surrounding applications.
            subprocess.run(["magick", str(path), "-crop", "920x330+980+80", "+repage", str(path)], check=True)
            print("capture", name, flush=True)
    code = process.wait()
    log = "".join(lines)
    (out / "wayland-result.txt").write_text(log)
    print(log[-4000:])
    raise SystemExit(0 if code == 0 and "PASS: companion material" in log and "FAIL:" not in log else 1)
