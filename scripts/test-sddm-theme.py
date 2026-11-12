#!/usr/bin/env python3
"""sddm/install.sh: themed copy, sddm.conf edit that keeps other lines, uninstall."""
import os
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
        self.wall.write_bytes(b"\x89PNG\r\n\x1a\nfake")
        self.palette(background="#14140c", on_surface="#e6e3d5", primary="#cbcb76")
        self.theme = self.root / "usr/share/sddm/themes/isla"

    def tearDown(self):
        self.tmp.cleanup()

    def palette(self, **colors):
        import json
        (self.cache / "matugen" / "palette.json").write_text(
            json.dumps({"wallpaper": str(self.wall), "colors": colors}))

    def run_install(self, *args):
        env = dict(os.environ, XDG_CACHE_HOME=str(self.cache), LANG="es_MX.UTF-8")
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
