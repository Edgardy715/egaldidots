#!/usr/bin/env python3
"""sddm/install.sh: themed copy, sddm.conf edit that keeps other lines, uninstall."""
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "sddm" / "install.sh"

CONF = """[Autologin]
Session=hyprland

[Theme]
Current=material-you
CursorTheme=Bibata

[Users]
MaximumUid=60513
"""


def tiny_png():
    import struct, zlib
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x40\x60\x80")) + chunk(b"IEND", b""))


class SddmTheme(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.root = t / "root"
        (self.root / "etc").mkdir(parents=True)
        self.conf = self.root / "etc" / "sddm.conf"
        self.conf.write_text(CONF)
        self.cache = t / "cache"
        (self.cache / "matugen").mkdir(parents=True)
        self.wall = t / "wall.png"
        self.wall.write_bytes(tiny_png())
        self.palette(background="#14140c", on_surface="#e6e3d5", primary="#cbcb76")
        self.theme = self.root / "usr/share/sddm/themes/isla"

    def tearDown(self):
        self.tmp.cleanup()

    def palette(self, **colors):
        import json
        (self.cache / "matugen" / "palette.json").write_text(
            json.dumps({"wallpaper": str(self.wall), "colors": colors}))

    def run_install(self, *args, env_extra=None):
        # Never read the real Isla config: point it at a missing file by default.
        env = dict(os.environ, XDG_CACHE_HOME=str(self.cache), LANG="es_MX.UTF-8",
                   ISLA_CONFIG=str(Path(self.tmp.name) / "none.json"))
        env.update(env_extra or {})
        return subprocess.run(["bash", str(INSTALL), "--root", str(self.root), *args],
                              env=env, capture_output=True, text=True, check=True)

    def test_install_themes_and_selects_isla(self):
        self.run_install()
        conf = (self.theme / "theme.conf").read_text()
        self.assertIn("bgColor=#14140c", conf)
        self.assertIn("accent=#cbcb76", conf)
        self.assertIn("background=background.png", conf)
        self.assertIn("locale=es_MX", conf)
        self.assertEqual((self.theme / "background.png").read_bytes(), self.wall.read_bytes())
        for f in ("Main.qml", "metadata.desktop", "theme.conf"):
            self.assertEqual((self.theme / f).stat().st_mode & 0o777, 0o644, f)
        text = self.conf.read_text()
        self.assertIn("Current=isla", text)
        self.assertNotIn("material-you", text)
        # Everything else in sddm.conf survives untouched.
        for line in ("Session=hyprland", "CursorTheme=Bibata", "[Users]", "MaximumUid=60513"):
            self.assertIn(line, text)
        self.assertEqual((self.theme / "previous-theme").read_text().strip(), "material-you")

    def test_lockscreen_components_are_bundled(self):
        self.run_install()
        for f in ("components/LockGlyph.qml", "components/LockButton.qml", "components/MaterialIcon.qml",
                  "components/AnimatedIconData.js", "shaders/drops.frag.qsb", "Singletons/qmldir",
                  "Singletons/Theme.qml", "Singletons/Flags.qml", "Singletons/Motion.qml"):
            self.assertEqual((self.theme / f).stat().st_mode & 0o777, 0o644, f)
        self.assertEqual((self.theme / "components").stat().st_mode & 0o777, 0o755)
        motion = (self.theme / "Singletons/Motion.qml").read_text()
        self.assertNotIn("import Quickshell", motion)
        self.assertIn("QtObject {", motion)

    @unittest.skipUnless(shutil.which("sddm-greeter-qt6"), "sddm-greeter-qt6 not installed")
    def test_greeter_loads_theme_without_qml_errors(self):
        self.run_install()
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_FORCE_STDERR_LOGGING="1")
        try:
            out = subprocess.run(["sddm-greeter-qt6", "--test-mode", "--theme", str(self.theme)],
                                 env=env, capture_output=True, text=True, timeout=6)
            text = out.stdout + out.stderr
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode() + (e.stderr or b"").decode()
        self.assertIn("Adding view", text)
        # QML warnings carry "file.qml:LINE"; a load failure says "Fallback".
        bad = [l for l in text.splitlines() if re.search(r"\.(qml|js):\d+", l) or "Fallback" in l]
        self.assertEqual(bad, [], text)

    def test_isla_preferences_reach_the_greeter(self):
        import json
        cfg = Path(self.tmp.name) / "shell.json"
        cfg.write_text(json.dumps({"appearance": {
            "reduceMotion": True, "time12h": False, "motionScale": 9, "fontScale": "1.2\nCurrent=evil"}}))
        self.run_install(env_extra={"ISLA_CONFIG": str(cfg)})
        conf = (self.theme / "theme.conf").read_text()
        for line in ("reduceMotion=true", "clock12h=false", "motionScale=2", "fontScale=1"):
            self.assertIn(line + "\n", conf)
        self.assertNotIn("evil", conf)

    def test_reinstall_keeps_original_previous_theme(self):
        self.run_install()
        self.run_install()
        self.assertEqual((self.theme / "previous-theme").read_text().strip(), "material-you")

    def test_untrusted_palette_values_are_dropped(self):
        self.palette(background="#14140c\nCurrent=evil", primary="red", error="#ffb4ab")
        self.run_install()
        conf = (self.theme / "theme.conf").read_text()
        self.assertNotIn("evil", conf)
        self.assertNotIn("accent=", conf)
        self.assertIn("error=#ffb4ab", conf)

    def test_conf_without_theme_section_gets_one(self):
        self.conf.write_text("[Autologin]\nSession=hyprland\n")
        self.run_install()
        self.assertTrue(self.conf.read_text().endswith("[Theme]\nCurrent=isla\n"))

    def test_uninstall_restores_previous_theme(self):
        self.run_install()
        out = self.run_install("--uninstall").stdout
        self.assertIn("material-you", out)
        self.assertFalse(self.theme.exists())
        text = self.conf.read_text()
        self.assertIn("Current=material-you", text)
        self.assertIn("CursorTheme=Bibata", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
