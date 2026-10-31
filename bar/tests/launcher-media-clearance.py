"""Closing the launcher with music: the real overlay with an isolated MPRIS fixture (Wayland)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
if not os.environ.get("WAYLAND_DISPLAY"):
    raise SystemExit("SKIP launcher-media-clearance: needs Wayland")
with tempfile.TemporaryDirectory(prefix="isla-launcher-media-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    players = root / "bar/Singletons/Players.qml"
    text = players.read_text()
    text = text.replace('    function isProxy(p) {', '''    property bool fixturePresent: true
    property bool fixturePlaying: true
    property QtObject fixture: QtObject {
        property bool isPlaying: root.fixturePlaying
        property string trackTitle: "Canción de prueba"
        property string trackArtist: "Artista de prueba"
        property string trackArtUrl: String(Qt.resolvedUrl("../tests/fixtures/artwork-coral.svg"))
        property string identity: "Spotify"
        property string desktopEntry: "spotify"
        property string dbusName: "org.mpris.MediaPlayer2.fixture"
        property var metadata: ({})
        property real length: 240
        property real position: 80
        property bool positionSupported: false
        property bool canControl: false
        property bool canSeek: false
        property bool canGoNext: false
        property bool canGoPrevious: false
        function togglePlaying() {}
        function next() {}
        function previous() {}
    }
    function isProxy(p) {''')
    text = text.replace('readonly property var list: {', 'readonly property var list: {\n        return root.fixturePresent ? [root.fixture] : []')
    players.write_text(text)
    (root / "shell.json").write_text("{}")
    env = dict(os.environ, ISLA_CONFIG=str(root / "shell.json"),
               XDG_STATE_HOME=str(root / "state"), QT_QPA_PLATFORM="wayland")
    with (root / "output.log").open("w+") as log:
        result = subprocess.run(["qs", "-p", str(root / "bar/launcher-media-clearance-regression.qml")],
                                env=env, stdout=log, stderr=log, timeout=180)
        log.seek(0)
        output = log.read()
        lines = [line for line in output.splitlines() if "clearance" in line or "FAIL" in line or "PASS" in line]
        print("\n".join(lines))
        print("exit", result.returncode)
        assert result.returncode == 0 and "FAIL" not in output and "PASS: launcher media clearance" in output
