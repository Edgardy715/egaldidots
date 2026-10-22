"""Load special-character paths in preview windows, without applying a wallpaper."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-wallpaper-source-") as directory:
    root = Path(directory)
    wallpapers = root / "wallpapers"
    wallpapers.mkdir()
    image = wallpapers / "fixture #? % á.png"
    subprocess.run(["magick", "-size", "128x72", "gradient:steelblue-coral", str(image)], check=True)
    config = root / "config.json"
    config.write_text(json.dumps({"paths": {"wallpaperDir": str(wallpapers),
                                           "wallpaperCacheDir": str(root / "thumbnails")}}))
    env = dict(os.environ, ISLA_CONFIG=str(config), ISLA_TEST_IMAGE=str(image),
               XDG_CACHE_HOME=str(root / "cache"), XDG_STATE_HOME=str(root / "state"),
               QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "offscreen"))
    result = subprocess.run(["qs", "-p", str(source / "wallpaper-source-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "PASS: overview and lockscreen" in output and "FAIL:" not in output
