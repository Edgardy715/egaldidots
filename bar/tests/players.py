#!/usr/bin/env python3
"""Exercise the real Players bindings with isolated, synthetic MPRIS players."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=ROOT / "Singletons/Players.qml")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="isla-players-") as directory:
    root = Path(directory)
    singletons = root / "Singletons"
    mocks = root / "mocks"
    singletons.mkdir()
    mocks.mkdir()
    source = args.source.read_text()
    assert "import Quickshell.Services.Mpris" in source
    (singletons / "Players.qml").write_text(source.replace(
        "import Quickshell.Services.Mpris", 'import "../mocks"'))
    shutil.copy(ROOT / "Singletons/MediaSource.js", singletons)
    (singletons / "qmldir").write_text("singleton Players 1.0 Players.qml\n")
    (mocks / "qmldir").write_text(
        "singleton Mpris 1.0 Mpris.qml\nsingleton MprisPlaybackState 1.0 MprisPlaybackState.qml\n")
    (mocks / "Mpris.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property QtObject players: QtObject { property var values: [] } }
''')
    (mocks / "MprisPlaybackState.qml").write_text('''pragma Singleton
import QtQuick
QtObject { enum State { Stopped, Playing, Paused } }
''')
    (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "Singletons"
import "mocks"
ShellRoot {
    id: test
    component Player: QtObject {
        property string dbusName: "org.mpris.MediaPlayer2.test"
        property int playbackState: MprisPlaybackState.Paused
        readonly property bool isPlaying: playbackState === MprisPlaybackState.Playing
        property bool positionSupported: false
        property string trackTitle: "Track"
        property string trackArtist: ""
        property string trackArtUrl: ""
        property string identity: "Test"
        property string desktopEntry: ""
        property var metadata: ({})
    }
    Player { id: a }
    Player { id: b }
    Player { id: proxy; dbusName: "org.mpris.MediaPlayer2.playerctld" }
    readonly property var observedActive: Players.active
    readonly property bool observedPlaying: Players.playing
    Connections {
        target: Players
        function onActiveChanged() {
            void test.observedActive
            void test.observedPlaying
        }
    }
    property int step: 0
    property int failures: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); test.failures++ }
    }
    Timer {
        interval: 10; running: true; repeat: true
        onTriggered: {
            switch (test.step++) {
            case 0:
                check(Players.active === null, "empty list")
                Mpris.players.values = [a, b, proxy]
                break
            case 1:
                check(Players.list.length === 2 && Players.active === a, "filter proxy and first fallback")
                b.playbackState = MprisPlaybackState.Playing
                break
            case 2:
                check(Players.active === b && Players.recent === b, "playing wins and is remembered")
                b.playbackState = MprisPlaybackState.Paused
                break
            case 3:
                check(Players.active === b, "recent wins when paused")
                a.playbackState = MprisPlaybackState.Playing
                break
            case 4:
                check(Players.active === a && Players.recent === a, "playing replaces recent")
                Players.manual = b
                break
            case 5:
                check(Players.active === b && !Players.playing && Players.recent === a, "live paused manual wins without replacing recent")
                Mpris.players.values = [a, proxy]
                break
            case 6:
                check(Players.active === a, "removed manual falls back to playing")
                Mpris.players.values = [a, b]
                Players.cycleManual(1)
                break
            case 7:
                check(Players.active === a, "cycle advances from live manual b to a")
                Players.cycleManual(-1)
                break
            case 8:
                check(Players.active === b, "negative cycle")
                b.playbackState = MprisPlaybackState.Stopped
                break
            case 9:
                check(Players.active === a && Players.list.length === 1, "stopped manual is filtered")
                a.playbackState = MprisPlaybackState.Paused
                break
            case 10:
                check(Players.active === a && !Players.playing, "remaining recent stays paused")
                Players.manual = null
                a.playbackState = MprisPlaybackState.Playing
                break
            case 11:
                b.playbackState = MprisPlaybackState.Paused
                Mpris.players.values = [b]
                break
            case 12:
                check(Players.active === b && Players.recent === a, "paused replacement must not become recent")
                Mpris.players.values = []
                break
            case 13:
                check(Players.active === null && !Players.has && !Players.playing, "all removed")
                if (!test.failures)
                    console.log("PASS: Players priority, recency, filtering, cycling and removal")
                Qt.exit(test.failures ? 1 : 0)
            }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    result = subprocess.run(["qs", "-p", str(root / "shell.qml")], env=env,
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "PASS: Players" in output and "FAIL:" not in output
    assert "Binding loop detected" not in output, "Players emitted a QML binding loop"
