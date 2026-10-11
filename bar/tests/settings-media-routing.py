"""Exercise real overlay routing with an isolated MPRIS fixture."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-settings-media-") as directory:
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
        property string trackArtUrl: ""
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
        result = subprocess.run(["qs", "-p", str(root / "bar/settings-media-routing-regression.qml")],
                                env=env, stdout=log, stderr=log, timeout=100)
        log.seek(0)
        output = log.read()
        print(output)
        print("exit", result.returncode)
        assert result.returncode == 0 and "FAIL" not in output and "PASS: settings media routing" in output
