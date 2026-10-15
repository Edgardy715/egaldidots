"""Exercise the rebuilt scanner against changed source and corrupt cache files."""

import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "bar/wallpaper-scanner-regression.qml"
PLUGIN = os.environ.get("ISLA_WPSCAN_BUILD")


with tempfile.TemporaryDirectory(prefix="isla-wpscan-test-") as directory:
    base = Path(directory)
    plugin = Path(PLUGIN) if PLUGIN else base / "build"
    if not PLUGIN:
        subprocess.run(["cmake", "-S", str(ROOT / "wpscan"), "-B", str(plugin),
                        "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release"], check=True, capture_output=True)
        subprocess.run(["cmake", "--build", str(plugin), "--parallel", "2"], check=True, capture_output=True)
    source = base / "wall #1?.png"
    cache = base / "cache"
    cache.mkdir()

    def run(ready):
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QML_IMPORT_PATH=str(plugin),
                   ISLA_SCAN_DIR=str(base), ISLA_SCAN_CACHE=str(cache),
                   ISLA_SCAN_READY="1" if ready else "0")
        result = subprocess.run(["quickshell", "-p", str(FIXTURE)], env=env,
                                capture_output=True, text=True, timeout=8)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "PASS:" in output, output

    Image.new("RGB", (640, 360), "#224466").save(source)
    run(False)
    run(True)
    modified = source.stat().st_mtime
    Image.new("RGB", (640, 360), "#884422").save(source)
    os.utime(source, (modified + 2, modified + 2))
    run(False)
    run(True)
    thumb = next(cache.glob("*.jpg"))
    thumb.write_bytes(b"invalid thumbnail")
    run(False)
    run(True)
    print("PASS: scanner invalidates changed source and corrupt thumbnail")
