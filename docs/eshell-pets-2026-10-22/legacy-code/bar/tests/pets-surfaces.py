#!/usr/bin/env python3
"""Test production pet routing with private player/wallpaper/audio data."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-pet-surfaces-") as directory:
    root = Path(directory)
    bar = root / "bar"
    shutil.copytree(source, bar, ignore=shutil.ignore_patterns("__pycache__"))
    players = bar / "Singletons/Players.qml"
    text = players.read_text()
    text = text.replace("    function isProxy(p) {", '''    property bool fixturePresent: true
    property QtObject fixture: QtObject {
        property bool isPlaying: true
        property bool canControl: true
        property bool canTogglePlaying: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool canGoNext: false
        property bool canGoPrevious: false
        property bool shuffleSupported: false
        property bool loopSupported: false
        property real rate: 1
        property real position: 30
        property real length: 240
        property string identity: "Fixture Music"
        property string desktopEntry: "vlc"
        property string dbusName: "org.mpris.MediaPlayer2.fixture"
        property string trackTitle: "A quiet afternoon"
        property string trackArtist: "Fixture artist"
        property string trackAlbum: "Fixture album"
        property string trackArtUrl: String(Qt.resolvedUrl("../tests/fixtures/artwork-coral.svg"))
        property int toggles: 0
        function togglePlaying() { toggles++; isPlaying = !isPlaying }
        function next() {}
        function previous() {}
    }
    function isProxy(p) {''')
    assert "property QtObject fixture:" in text
    assert "readonly property var list: {" in text
    text = text.replace("readonly property var list: {", "readonly property var list: {\n        return root.fixturePresent ? [root.fixture] : []")
    text = text.replace("running: root.live && root.active.positionSupported", "running: false")
    players.write_text(text)
    (bar / "Singletons/Cava.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool available: false
    property bool hasFrame: false
    property var values: []
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
    (bar / "Singletons/Wallpapers.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    id: root
    property var list: [entry("artwork-coral.svg"), entry("artwork-blue.svg"), entry("artwork-green.svg")]
    readonly property int count: list.length
    property bool applying: false
    property bool scanning: false
    property string current: ""
    property string lastAttemptPath: ""
    property string applyPhase: "idle"
    property string applyError: ""
    property int attempts: 0
    signal applyFinished(string path, bool success)
    signal thumbUpdated(string path, string thumbSource, int cacheRevision)
    signal thumbFailed(string path)
    function entry(name, title) {
        const url = String(Qt.resolvedUrl("../tests/fixtures/" + name))
        return {path: decodeURIComponent(url.slice(7)), baseName: title || name,
            thumb: decodeURIComponent(url.slice(7)), thumbSource: url, thumbReady: true,
            thumbFailed: false, cacheRevision: 0}
    }
    function forceRefresh() {}
    function requestThumbnail(path, thumb) {}
    function accentFor(path, fallback) { return fallback }
    function setWallpaper(path) { attempts++; lastAttemptPath = path; applying = true; applyPhase = "applying"; return true }
    function finish(path, success) {
        applying = false
        applyPhase = success ? "done" : "error"
        applyError = success ? "" : "Fixture failure"
        if (success) current = path
        applyFinished(path, success)
    }
}
''')
    config = root / "shell.json"
    config.write_text(json.dumps({"pets": {"enabled": True}, "modules": {
        "systemStatus": False, "userAvatar": False}, "appearance": {"reduceMotion": False}}))
    env = dict(os.environ, ISLA_CONFIG=str(config), XDG_STATE_HOME=str(root / "state"),
               QT_QPA_PLATFORM="wayland")
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        env["ISLA_TEST_OUTPUT"] = str(args.output.resolve())
    result = subprocess.run(["quickshell", "-p", str(bar / "pets-surfaces-regression.qml")],
                            env=env, capture_output=True, text=True, timeout=65)
    log = result.stdout + result.stderr
    if args.output:
        (args.output / "surfaces.log").write_text(log)
    print(log)
    assert result.returncode == 0 and "PASS: pets surface routing" in log and "FAIL" not in log
    assert not any(error in log for error in ("ReferenceError:", "TypeError:", "Binding loop", "Cannot assign", "Unable to assign")), "QML error"
