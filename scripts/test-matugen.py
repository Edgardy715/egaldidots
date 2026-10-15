#!/usr/bin/env python3
"""Isolated transaction checks for the Matugen wallpaper pipeline."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "matugen/.config/matugen/generate.py"


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "config"
        self.cache = self.root / "cache" / "matugen"
        self.generator = self.config / "matugen/generate.py"
        self.generator.parent.mkdir(parents=True)
        shutil.copy2(SOURCE, self.generator)
        templates = self.generator.parent / "templates"
        templates.mkdir()
        (templates / "color.txt").write_text("{{ colors.primary.default.hex }}\n")
        (templates / "manifest.json").write_text(
            json.dumps([{"input": "color.txt", "output": "color.txt"}]))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.wall = self.root / "wall paper.png"
        self.wall.write_bytes(b"fake image for mocked Matugen")
        self.other_wall = self.root / "other wall.png"
        self.other_wall.write_bytes(b"different fake image")
        (self.bin / "matugen").write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys, time, tomllib
args = sys.argv[1:]
mode = args[args.index('-m') + 1]
config = pathlib.Path(args[args.index('-c') + 1])
if os.environ.get('MOCK_MATUGEN_FAIL') == '1': sys.exit(7)
time.sleep(float(os.environ.get('MOCK_DELAY', '0')))
data = tomllib.loads(config.read_text())
if os.environ.get('MOCK_RENDER_FAIL') != '1':
    for entry in data['templates'].values():
        pathlib.Path(entry['output_path']).write_text('#abcdef\\n')
roles = 'surface background on_surface on_surface_variant primary on_primary primary_container on_primary_container secondary on_secondary secondary_container on_secondary_container tertiary on_tertiary tertiary_container on_tertiary_container error on_error error_container on_error_container outline outline_variant surface_container surface_container_low surface_container_high surface_container_highest surface_container_lowest'.split()
colors = {role: {'dark': {'color': '#123456'}, 'light': {'color': '#abcdef'}} for role in roles}
base16 = {f'base{i:02x}': {'dark': {'color': '#123456'}, 'light': {'color': '#abcdef'}} for i in range(16)}
base16['base00']['dark']['color'] = '#010203'
base16['base05']['dark']['color'] = '#fefdfc'
print(json.dumps({'colors': colors, 'base16': base16}))
''')
        (self.bin / "awww").write_text('''#!/usr/bin/env python3
import os, pathlib, sys
pathlib.Path(os.environ['MOCK_AWWW_LOG']).open('a').write(' '.join(sys.argv[1:]) + '\\n')
if os.environ.get('MOCK_POST_AWWW_CONFLICT') == '1':
    target = pathlib.Path(os.environ['XDG_CACHE_HOME']) / 'matugen/outputs/color.txt'
    target.unlink()
    target.write_text('foreign output')
sys.exit(9 if os.environ.get('MOCK_AWWW_FAIL') == '1' else 0)
''')
        for binary in ("matugen", "awww"):
            (self.bin / binary).chmod(0o755)
        for binary in ("fish", "hyprctl"):
            stub = self.bin / binary
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        (self.bin / "hyprctl").write_text("#!/bin/sh\nif [ \"$1\" = monitors ]; then printf '%s' \"${MOCK_MONITORS:-}\"; fi\n")
        pgrep = self.bin / "pgrep"
        pgrep.write_text("#!/bin/sh\ncase \" ${MOCK_RUNNING_NAMES:-} \" in *\" $2 \"*) exit 0;; *) exit 1;; esac\n")
        pgrep.chmod(0o755)
        for binary in ("swaync-client", "pkill"):
            stub = self.bin / binary
            stub.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$MOCK_CLIENT_LOG\"\n")
            stub.chmod(0o755)
        quickshell = self.bin / "quickshell"
        quickshell.write_text("#!/bin/sh\n"
                              "if [ \"$3\" = list ]; then\n"
                              "  if [ \"${MOCK_QS_ABSENT:-}\" = 1 ]; then echo '[]'; else echo '[{\"id\":\"mock\"}]'; fi\n"
                              "  exit 0\nfi\n"
                              "printf '%s\\n' \"$*\" >> \"$MOCK_QS_LOG\"\n"
                              "[ \"$#\" -eq 6 ] || { echo 'Wrong IPC arity'; exit 1; }\n"
                              "[ \"${MOCK_QS_RELOAD_FAIL:-}\" != 1 ]\n")
        quickshell.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(XDG_CONFIG_HOME=str(self.config), XDG_CACHE_HOME=str(self.root / "cache"),
                        PATH=f"{self.bin}:{os.environ['PATH']}",
                        MOCK_AWWW_LOG=str(self.root / "awww.log"),
                        MOCK_QS_LOG=str(self.root / "qs.log"),
                        MOCK_ROFI_LOG=str(self.root / "rofi.log"),
                        MOCK_CLIENT_LOG=str(self.root / "clients.log"))

    def run_generator(self, *args, env=None):
        return subprocess.run([sys.executable, str(self.generator), *map(str, args)],
                              env=env or self.env, text=True, capture_output=True)

    def test_seed_publishes_complete_palette_without_wallpaper_change(self):
        result = self.run_generator("--seed", self.wall)
        self.assertEqual(result.returncode, 0, result.stderr)
        palette = json.loads((self.cache / "palette.json").read_text())
        self.assertEqual((palette["version"], palette["generator"], palette["mode"]),
                         (1, "matugen", "dark"))
        self.assertEqual(palette["wallpaper"], str(self.wall))
        self.assertEqual(palette["colors"]["primary"], "#123456")
        self.assertEqual(palette["colors"]["surface_container"], "#123456")
        self.assertEqual(palette["schemes"]["light"]["primary"], "#abcdef")
        self.assertEqual(len([k for k in palette["terminal"] if k.startswith("color")]), 16)
        self.assertEqual(palette["terminal"]["background"], "#010203")
        self.assertEqual(palette["terminal"]["foreground"], "#fefdfc")
        self.assertEqual((self.cache / "outputs/color.txt").read_text(), "#abcdef\n")
        self.assertFalse((self.root / "awww.log").exists())
        self.assertFalse((self.root / "rofi.log").exists())
        self.assertEqual((self.cache / "current-wallpaper").resolve(), self.wall)
        self.assertEqual((self.cache / "wallpaper.txt").read_text(), f"{self.wall}\n")
        self.assertEqual(os.readlink(self.cache / "wallpaper.txt"), "current/wallpaper.txt")

    def test_failed_generation_and_awww_preserve_previous_generation(self):
        self.assertEqual(self.run_generator("--seed", self.wall).returncode, 0)
        old = os.readlink(self.cache / "current")
        old_marker = (self.cache / "current-wallpaper").resolve()
        old_text = (self.cache / "wallpaper.txt").read_text()
        for flag in ("MOCK_MATUGEN_FAIL", "MOCK_RENDER_FAIL", "MOCK_AWWW_FAIL"):
            env = dict(self.env, **{flag: "1"})
            result = self.run_generator(self.other_wall, env=env)
            self.assertNotEqual(result.returncode, 0, flag)
            self.assertEqual(os.readlink(self.cache / "current"), old)
            self.assertEqual((self.cache / "palette.json").read_text(),
                             (self.cache / old / "palette.json").read_text())
            self.assertEqual((self.cache / "current-wallpaper").resolve(), old_marker)
            self.assertEqual((self.cache / "wallpaper.txt").read_text(), old_text)

    def test_refresh_and_light_mode_do_not_apply_wallpaper(self):
        self.assertEqual(self.run_generator("--seed", self.wall).returncode, 0)
        result = self.run_generator("--refresh", "--mode", "light")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.cache / "palette.json").read_text())["colors"]["primary"],
                         "#abcdef")
        self.assertFalse((self.root / "awww.log").exists())

    def test_publish_failure_after_awww_reports_partial_apply(self):
        self.assertEqual(self.run_generator("--seed", self.wall).returncode, 0)
        old = os.readlink(self.cache / "current")
        result = self.run_generator(self.other_wall,
                                    env=dict(self.env, MOCK_POST_AWWW_CONFLICT="1"))
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("wallpaper changed but palette generation failed", result.stderr)
        self.assertEqual(os.readlink(self.cache / "current"), old)
        self.assertEqual((self.cache / "current-wallpaper").resolve(), self.wall)
        self.assertIn(str(self.other_wall), (self.root / "awww.log").read_text())

    def test_successful_apply_switches_wallpaper_and_palette(self):
        self.assertEqual(self.run_generator("--seed", self.wall).returncode, 0)
        result = self.run_generator(self.other_wall)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("ISLA_WALLPAPER_HANDOFF", result.stdout)
        self.assertEqual((self.cache / "current-wallpaper").resolve(), self.other_wall)
        self.assertEqual((self.cache / "wallpaper.txt").read_text(), f"{self.other_wall}\n")
        self.assertEqual(json.loads((self.cache / "palette.json").read_text())["wallpaper"],
                         str(self.other_wall))
        command = (self.root / "awww.log").read_text()
        self.assertIn("--transition-type grow --transition-pos top", command)
        self.assertIn("--transition-duration 1.45", command)
        self.assertIn("--transition-bezier 0.65,0,0.35,1 --transition-step 35 --transition-fps 144", command)
        self.assertEqual((self.root / "qs.log").read_text().splitlines(),
                         [f"-p {self.config}/quickshell/bar ipc call island reloadColors"])
        self.assertNotIn("optional Isla reload failed", result.stderr)
        self.assertFalse((self.root / "rofi.log").exists())
        self.assertFalse((self.root / "clients.log").exists())

    def test_transition_matches_monitor_refresh_with_bounded_cost(self):
        for rate, expected in [(59.94, 60), (239.964, 240), (360, 240)]:
            with self.subTest(rate=rate):
                result = self.run_generator(self.wall, env=dict(self.env, MOCK_MONITORS=json.dumps([
                    {"refreshRate": rate, "disabled": False}])))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"--transition-fps {expected}", (self.root / "awww.log").read_text().splitlines()[-1])

    def test_reduced_motion_avoids_spatial_transition(self):
        result = self.run_generator(self.wall, "--reduce-motion")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--transition-type none", (self.root / "awww.log").read_text())

    def test_isla_feedback_handoff_precedes_awww_and_holds_confirmation(self):
        process = subprocess.Popen([sys.executable, str(self.generator), "--isla-feedback", str(self.wall)],
                                   env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            self.assertEqual(process.stdout.readline(), "ISLA_WALLPAPER_HANDOFF\n")
            handoff = time.monotonic()
            output, error = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, error)
            self.assertGreaterEqual(time.monotonic() - handoff, 1.4)
            self.assertIn("matugen: published", output)
            self.assertTrue((self.root / "awww.log").exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_isla_feedback_only_announces_prepared_apply(self):
        self.assertEqual(self.run_generator("--seed", self.wall, "--isla-feedback").returncode, 0)
        self.assertNotIn("ISLA_WALLPAPER_HANDOFF", self.run_generator("--refresh", "--isla-feedback").stdout)
        self.assertFalse((self.root / "awww.log").exists())
        for flag in ("MOCK_MATUGEN_FAIL", "MOCK_RENDER_FAIL"):
            with self.subTest(flag=flag):
                result = self.run_generator(self.other_wall, "--isla-feedback", env=dict(self.env, **{flag: "1"}))
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("ISLA_WALLPAPER_HANDOFF", result.stdout)
        (self.cache / "outputs/color.txt").unlink()
        (self.cache / "outputs/color.txt").write_text("foreign output")
        result = self.run_generator(self.other_wall, "--isla-feedback")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("ISLA_WALLPAPER_HANDOFF", result.stdout)
        self.assertFalse((self.root / "awww.log").exists())

    def test_isla_feedback_does_not_announce_missing_awww(self):
        preflight_bin = self.root / "preflight-bin"
        preflight_bin.mkdir()
        (preflight_bin / "matugen").symlink_to(self.bin / "matugen")
        (preflight_bin / "python3").symlink_to(sys.executable)
        result = self.run_generator(self.wall, "--isla-feedback",
                                    env=dict(self.env, PATH=str(preflight_bin)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("awww executable is unavailable", result.stderr)
        self.assertNotIn("ISLA_WALLPAPER_HANDOFF", result.stdout)
        self.assertFalse((self.root / "awww.log").exists())

    def test_reduced_motion_feedback_has_no_close_delay(self):
        start = time.monotonic()
        result = self.run_generator(self.wall, "--reduce-motion", "--isla-feedback")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[0], "ISLA_WALLPAPER_HANDOFF")
        self.assertLess(time.monotonic() - start, 0.42)
        self.assertIn("--transition-type none", (self.root / "awww.log").read_text())

    def test_absent_shell_does_not_make_apply_fail(self):
        result = self.run_generator(self.wall, env=dict(self.env, MOCK_QS_ABSENT="1"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "qs.log").exists())

    def test_running_shell_reload_failure_reports_partial_apply(self):
        result = self.run_generator(self.wall, env=dict(self.env, MOCK_QS_RELOAD_FAIL="1"))
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("palette published but live reload failed", result.stderr)
        self.assertEqual((self.cache / "current-wallpaper").resolve(), self.wall)

    def test_only_running_optional_clients_are_reloaded(self):
        env = dict(self.env, MOCK_RUNNING_NAMES="swaync kitty")
        result = self.run_generator("--refresh", env=env)
        self.assertNotEqual(result.returncode, 0)  # No prior current wallpaper.
        self.assertFalse((self.root / "clients.log").exists())
        self.assertEqual(self.run_generator("--seed", self.wall).returncode, 0)
        result = self.run_generator("--refresh", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "clients.log").read_text().splitlines(),
                         ["-USR1 -x kitty"])

    def test_concurrent_seeds_publish_whole_generation(self):
        env = dict(self.env, MOCK_DELAY="0.2")
        command = [sys.executable, str(self.generator), "--seed", str(self.wall)]
        first = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for process in (first, second):
            _, error = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, error)
        self.assertEqual((self.cache / "outputs/color.txt").read_text(), "#abcdef\n")
        self.assertEqual(len(list((self.cache / "generations").iterdir())), 2)

    @unittest.skipUnless((Path.home() / ".local/bin/matugen").is_file() and shutil.which("magick"),
                         "Real Matugen and ImageMagick are required for native template smoke")
    def test_real_kitty_template_matches_canonical_terminal(self):
        real_matugen = Path.home() / ".local/bin/matugen"
        image = self.root / "real image.png"
        subprocess.run(["magick", "-size", "3x3", "xc:#b06060", str(image)], check=True)
        env = dict(self.env, PATH=f"{real_matugen.parent}:{os.environ['PATH']}")
        result = subprocess.run([sys.executable, str(SOURCE), "--seed", str(image)],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        palette = json.loads((self.cache / "palette.json").read_text())
        kitty = dict(line.split(maxsplit=1) for line in
                     (self.cache / "outputs/colors-kitty.conf").read_text().splitlines()
                     if line and not line.startswith("#"))
        self.assertEqual(palette["terminal"]["background"], kitty["background"])
        self.assertEqual(palette["terminal"]["foreground"], kitty["foreground"])
        self.assertEqual(palette["terminal"]["color0"], kitty["color0"])
        self.assertEqual(palette["terminal"]["color7"], kitty["color7"])


if __name__ == "__main__":
    unittest.main()
