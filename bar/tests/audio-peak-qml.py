#!/usr/bin/env python3
"""Real QML controller reopen with native/fallback and a private silent monitor."""
import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
helpers = runpy.run_path(str(ROOT / "bar/tests/cava-hybrid-performance.py"))
pactl, tree, stop = (helpers[key] for key in ("pactl", "tree", "stop"))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--library", type=Path, required=True)
args = parser.parse_args()
defaults = pactl("get-default-sink"), pactl("get-default-source")
sink = "isla_peak_qml_" + str(os.getpid())
module = None
try:
    module = pactl("load-module", "module-null-sink", "sink_name=" + sink)
    assert defaults == (pactl("get-default-sink"), pactl("get-default-source"))
    with tempfile.TemporaryDirectory(prefix="isla-peak-qml-") as tmp:
        temp = Path(tmp)
        fixture = temp / "test.qml"
        source = (ROOT / "bar/audio-controller-regression.qml").read_text()
        source = source.replace('import "components"', 'import "' + (ROOT / "bar/components").as_uri() + '"')
        source = source.replace('audio.outputs.find(row => row.name === audio.defaultOutput) || audio.outputs[0]',
                                'audio.outputs.find(row => row.name === ' + json.dumps(sink) + ')')
        source = source.replace('compare(audio.error, "")', 'compare(audio.error, ""); wait(250)')
        fixture.write_text(source)
        config = temp / "config.json"
        config.write_text("{}")
        for backend in ("fallback", "native"):
            data = temp / backend
            if backend == "native":
                target = data / "isla/lib/libisla_audio_peak.so"
                target.parent.mkdir(parents=True)
                shutil.copy2(args.library, target)
            env = {**os.environ, "XDG_DATA_HOME": str(data), "ISLA_CONFIG": str(config),
                   "XDG_CACHE_HOME": str(temp / "cache"), "QT_QPA_PLATFORM": "offscreen"}
            process = subprocess.Popen(["qs", "-p", str(fixture)], env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            observed, bridges = set(), set()
            try:
                deadline = time.monotonic() + 10
                while process.poll() is None and time.monotonic() < deadline:
                    children = tree(process.pid)
                    observed.update(set(children) - {process.pid})
                    for pid, row in children.items():
                        if any(arg.endswith("/audio_bridge.py") for arg in row["argv"]):
                            try:
                                maps = Path(f"/proc/{pid}/maps").read_text()
                            except FileNotFoundError:
                                continue
                            if "/isla/lib/libisla_audio_peak.so" in maps:
                                bridges.add(pid)
                    time.sleep(.01)
                output, _ = process.communicate(timeout=2)
                assert process.returncode == 0 and "PASS: real audio controller" in output, output
                assert bool(bridges) == (backend == "native"), (backend, bridges)
                deadline = time.monotonic() + 3
                while any(tree(pid) for pid in observed) and time.monotonic() < deadline:
                    time.sleep(.02)
                assert not [pid for pid in observed if tree(pid)], "children survived controller close"
                print("PASS:", backend, "QML snapshot, private silent meter, close/reopen, maps and cleanup")
            finally:
                stop(process)
finally:
    if module is not None:
        pactl("unload-module", module)
    assert defaults == (pactl("get-default-sink"), pactl("get-default-source"))
print("PASS: private sink removed and defaults preserved")
