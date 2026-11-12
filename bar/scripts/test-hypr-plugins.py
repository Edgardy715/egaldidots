#!/usr/bin/env python3
"""Offline tests for hypr-plugins.py: fake hyprctl, local git repo, temp data dir."""
import json, os, subprocess, tempfile, textwrap, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "hypr-plugins.py"
COMMIT = "a" * 40


def sh(cmd, cwd=None, env=None):
    subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, env=env)


class Fixture:
    def __init__(self, loaded=True):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.data, self.cache = t / "data", t / "cache"
        (self.data / "demo").mkdir(parents=True)
        self.set_loaded(loaded)
        (t / "hyprctl").write_text(textwrap.dedent(f"""\
            #!/usr/bin/env python3
            import sys, json, pathlib
            a = sys.argv[1:]
            if "version" in a: print(json.dumps({{"version": "9.9.9", "commit": "{COMMIT}"}}))
            elif "plugin" in a:
                f = pathlib.Path("{t}/loaded.json"); print(f.read_text() if f.exists() else "[]")
            """))
        (t / "hyprctl").chmod(0o755)
        self.repo = t / "repo"
        self.make_repo("1.0.0", COMMIT)
        (t / "registry.json").write_text(json.dumps({"demo": {
            "name": "demo", "label": "Demo", "repo": str(self.repo), "channel": "tag",
            "dest": "demo/demo.so", "built": "demo.so",
            "build": [["sh", "build.sh", "{version}"]]}}))
        self.env = dict(os.environ, ISLA_PLUGIN_DIR=str(self.data), ISLA_HYPRCTL=str(t / "hyprctl"),
                        ISLA_PLUGIN_REGISTRY=str(t / "registry.json"), ISLA_HYPR_HEADERS=str(t / "none.h"), XDG_CACHE_HOME=str(self.cache))
        self.t = t

    def set_loaded(self, loaded, version="1.0.0"):
        (Path(self.tmp.name) / "loaded.json").write_text(
            json.dumps([{"name": "demo", "version": version}] if loaded else []))

    def make_repo(self, version, commit, fail=False):
        self.repo.mkdir(exist_ok=True)
        (self.repo / "build.sh").write_text("exit 1\n" if fail else f'printf "ABI {commit} v$1" > demo.so\n')
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
        if not (self.repo / ".git").exists():
            sh(["git", "init", "-q"], self.repo)
        sh(["git", "add", "-A"], self.repo)
        sh(["git", "commit", "-qm", version, "--allow-empty"], self.repo, env)
        sh(["git", "tag", "-f", "v" + version], self.repo)

    def install(self, text):
        (self.data / "demo/demo.so").write_text(text)

    def run(self, *args):
        out = subprocess.run(["python3", str(SCRIPT), *args], env=self.env, capture_output=True, text=True)
        return json.loads(out.stdout)


class Tests(unittest.TestCase):
    def test_states(self):
        f = Fixture(loaded=True)
        self.assertEqual(f.run("status")["plugins"][0]["state"], "missing")
        f.install("old ABI " + "b" * 40)
        p = f.run("status")
        self.assertEqual((p["plugins"][0]["state"], p["staleCount"]), ("incompatible", 1))
        f.install("ABI " + COMMIT)
        self.assertEqual(f.run("status")["plugins"][0]["state"], "loaded")
        f.set_loaded(False)
        self.assertEqual(f.run("status")["plugins"][0]["state"], "paused")

    def test_check_reports_update(self):
        f = Fixture()
        f.install("ABI " + COMMIT)
        self.assertFalse(f.run("check")["plugins"][0]["updateAvailable"])
        f.make_repo("1.1.0", COMMIT)
        p = f.run("check")["plugins"][0]
        self.assertEqual((p["latest"], p["updateAvailable"]), ("1.1.0", True))

    def test_update_swaps_atomically_with_backup(self):
        f = Fixture()
        f.install("ABI " + COMMIT + " old")
        f.make_repo("1.1.0", COMMIT)
        r = f.run("update", "demo")
        self.assertTrue(r["ok"], r)
        self.assertIn("v1.1.0", (f.data / "demo/demo.so").read_text())
        self.assertIn("old", Path(r["backup"]).read_text())
        self.assertEqual(json.loads((f.data / "demo/demo.meta.json").read_text())["version"], "1.1.0")
        self.assertEqual([p.name for p in (f.data / "demo").glob(".*")], [])
        self.assertTrue(f.run("status")["plugins"][0]["restartRequired"])
        self.assertEqual(list(f.cache.glob("plugin-build-*")), [])

    def test_incompatible_build_keeps_installed(self):
        f = Fixture()
        f.install("ABI " + COMMIT + " keep")
        f.make_repo("1.1.0", "c" * 40)
        r = f.run("update", "demo")
        self.assertFalse(r["ok"])
        self.assertIn("keep", (f.data / "demo/demo.so").read_text())

    def test_failed_build_keeps_installed(self):
        f = Fixture()
        f.install("ABI " + COMMIT + " keep")
        f.make_repo("1.1.0", COMMIT, fail=True)
        self.assertFalse(f.run("update", "demo")["ok"])
        self.assertIn("keep", (f.data / "demo/demo.so").read_text())

    def test_backups_never_overwrite(self):
        f = Fixture()
        f.install("ABI " + COMMIT + " v1")
        f.make_repo("1.1.0", COMMIT)
        a = f.run("update", "demo")["backup"]
        import time; time.sleep(1.1)
        f.make_repo("1.2.0", COMMIT)
        b = f.run("update", "demo")["backup"]
        self.assertNotEqual(a, b)
        self.assertIn("v1", Path(a).read_text())

    def test_headers_ahead_of_running_make_plugin_stale(self):
        f = Fixture()
        f.install("ABI " + COMMIT)
        h = f.t / "version.h"
        h.write_text('#define GIT_COMMIT_HASH "%s"\n' % ("d" * 40))
        f.env["ISLA_HYPR_HEADERS"] = str(h)
        self.assertEqual(f.run("status")["plugins"][0]["state"], "incompatible")

    def test_unknown_plugin(self):
        self.assertFalse(Fixture().run("update", "nope")["ok"])


if __name__ == "__main__":
    unittest.main()
