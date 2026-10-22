"""Exercise the real envelope with synthetic frames and capture processes disabled."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--baseline", action="store_true")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="isla-envelope-") as directory:
    root = Path(directory)
    shutil.copytree(args.source, root / "bar")
    shutil.copy(Path(__file__).resolve().parents[1] / "cava-envelope-regression.qml", root / "bar")
    source = root / "bar/Singletons/Cava.qml"
    text = source.read_text()
    assert "running: root.wanted && root.available && !sourceRestart.running" in text
    text = text.replace("running: root.wanted && root.available && !sourceRestart.running", "running: false")
    text = text.replace("Component.onCompleted: probe.running = true", "Component.onCompleted: {}")
    text = text.replace("onWantedChanged: if (root.wanted && !root.available) probe.running = true", "onWantedChanged: {}")
    source.write_text(text)
    (root / "config.json").write_text("{}")
    env = dict(os.environ, ISLA_CONFIG=str(root / "config.json"), QT_QPA_PLATFORM="offscreen",
               XDG_STATE_HOME=str(root / "state"), ISLA_EXPECT_BASELINE="1" if args.baseline else "0")
    result = subprocess.run(["qs", "-p", str(root / "bar/cava-envelope-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "PASS:" in output and "FAIL:" not in output
