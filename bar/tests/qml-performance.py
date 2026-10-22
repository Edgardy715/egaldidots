"""Measure production QML bindings with isolated media/CAVA; never control playback."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--baseline", action="store_true")
parser.add_argument("--output", type=Path)
args = parser.parse_args()
fixture = Path(__file__).resolve().parents[1] / "qml-performance-regression.qml"
with tempfile.TemporaryDirectory(prefix="isla-qml-perf-") as directory:
    root = Path(directory)
    bar = root / "bar"
    shutil.copytree(args.source, bar)
    shutil.copyfile(fixture, bar / fixture.name)
    overlay = bar / "windows/IslandOverlay.qml"
    overlay.write_text(overlay.read_text().replace("    id: overlay", "    id: overlay\n    readonly property alias perfPolicy: inputPolicy"))
    players = bar / "Singletons/Players.qml"
    text = players.read_text()
    text = text.replace("    function isProxy(p) {", '''    property QtObject fixture: QtObject {
        property bool isPlaying: true
        property bool canControl: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool canGoNext: false
        property bool canGoPrevious: false
        property bool canTogglePlaying: true
        property bool shuffleSupported: false
        property bool loopSupported: false
        property real rate: 1
        property real position: 30
        property real length: 240
        property string identity: "Spotify"
        property string desktopEntry: "spotify"
        property string dbusName: "org.mpris.MediaPlayer2.fixture"
        property string trackTitle: "Fixed metadata"
        property string trackArtist: "Fixture"
        property string trackAlbum: "Performance"
        property string trackArtUrl: String(Qt.resolvedUrl("../tests/fixtures/artwork-coral.svg"))
    }
    function isProxy(p) {''')
    text = text.replace("readonly property var list: {", "readonly property var list: {\n        return [root.fixture]")
    text = text.replace("running: root.live && root.active.positionSupported", "running: false")
    players.write_text(text)
    (bar / "Singletons/Cava.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool available: false
    property bool hasFrame: true
    property var values: Array(24).fill(0.4)
    property var consumers: ({})
    function setConsumer(id, active) {
        const next = Object.assign({}, consumers)
        if (active) next[id] = true
        else delete next[id]
        consumers = next
    }
}
''')
    (bar / "Singletons/MediaPalette.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton { property color accent: Theme.accent }
''')
    shutil.copyfile(fixture.parent / "tests/PerfCounters.js", bar / "tests/PerfCounters.js")
    spectrum = bar / "Singletons/Spectrum.js"
    spectrum.write_text('.import "../tests/PerfCounters.js" as Perf\n' + spectrum.read_text().replace(
        "function band(values, index, count) {", "function band(values, index, count) {\n    Perf.bands++"))
    (root / "config.json").write_text("{}")
    env = dict(os.environ, ISLA_CONFIG=str(root / "config.json"),
               XDG_STATE_HOME=str(root / "state"), ISLA_PERF_BASELINE="1" if args.baseline else "0",
               QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "wayland"))
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        env["ISLA_TEST_OUTPUT"] = str(args.output.resolve())
    timing = {}
    started = time.monotonic()
    with (root / "output.log").open("w+") as log:
        process = subprocess.Popen(["quickshell", "-p", str(bar / fixture.name)], env=env,
                                   stdout=log, stderr=log)
        try:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > 45:
                    raise TimeoutError("QML performance fixture exceeded 45 seconds")
                output = (root / "output.log").read_text()
                if "Configuration Loaded" in output and "loadedMs" not in timing:
                    timing["loadedMs"] = round(elapsed * 1000)
                if "QML_READY" in output and "readyMs" not in timing:
                    timing["readyMs"] = round(elapsed * 1000)
                    memory = Path(f"/proc/{process.pid}/smaps_rollup").read_text()
                    for line in memory.splitlines():
                        if line.startswith(("Rss:", "Pss:")):
                            key, value, _ = line.split()
                            timing[key.rstrip(":") + "KiB"] = int(value)
                time.sleep(0.025)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()
        log.seek(0)
        output = log.read()
    print(output)
    print("exit", process.returncode)
    assert process.returncode == 0 and "FAIL" not in output and "PASS: QML performance" in output
    measurements = [json.loads(line.split("QML_PERF ", 1)[1]) for line in output.splitlines() if "QML_PERF " in line]
    assert len(measurements) == 1
    measurements[0].update(timing)
    print("fixture timing/memory", json.dumps(timing))
    if args.output:
        (args.output / "measurements.json").write_text(json.dumps(measurements[0], indent=2) + "\n")
