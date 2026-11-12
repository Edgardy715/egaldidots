#!/usr/bin/env python3
"""Offline tests for hypr-binds.py (fake catalog and hyprctl, no reload)."""
import json, os, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "hypr-binds.py"
CAT = [
    {"id": "a.one", "label": "Uno", "group": "G", "default": "SUPER + A", "key": "SUPER + A", "enabled": True},
    {"id": "a.two", "label": "Dos", "group": "G", "default": "SUPER + SHIFT + B", "key": "SUPER + SHIFT + B", "enabled": True},
    {"id": "m.vol", "label": "Vol", "group": "M", "default": "XF86AudioMute", "key": "XF86AudioMute", "enabled": True},
]


class Fx:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "cat.json").write_text(json.dumps({"version": 1, "binds": CAT}))
        (t / "hyprctl").write_text('#!/usr/bin/env python3\nimport json\nprint(json.dumps([{"modmask":64,"key":"T","submap":"","description":""}]))\n')
        (t / "hyprctl").chmod(0o755)
        self.user = t / "binds.user.json"
        self.env = dict(os.environ, ISLA_BINDS_USER=str(self.user), ISLA_BINDS_CATALOG=str(t / "cat.json"),
                        ISLA_HYPRCTL=str(t / "hyprctl"), ISLA_NO_RELOAD="1")

    def run(self, *a):
        r = subprocess.run(["python3", str(SCRIPT), *a], env=self.env, capture_output=True, text=True)
        return json.loads(r.stdout)

    def saved_all(self):
        return json.loads(self.user.read_text())

    def saved(self):
        return json.loads(self.user.read_text())["binds"]


class T(unittest.TestCase):
    def test_bare_function_keys_allowed(self):
        f = Fx()
        self.assertTrue(f.run("set", "a.one", "F9")["ok"])

    def test_reset_and_enable_check_conflicts(self):
        f = Fx()
        cat = json.loads((f.user.parent / "cat.json").read_text())
        cat["binds"][0]["key"] = "SUPER + X"; cat["binds"][1]["key"] = "SUPER + A"
        (f.user.parent / "cat.json").write_text(json.dumps(cat))
        f.user.write_text(json.dumps({"version": 1, "binds": {"a.one": {"key": "SUPER + X"}}}))
        r = f.run("reset", "a.one")
        self.assertFalse(r["ok"], r)
        self.assertEqual(f.saved()["a.one"], {"key": "SUPER + X"})

    def test_backups_keep_every_write(self):
        f = Fx()
        for k in "XYZW":
            f.run("set", "a.one", "SUPER + " + k)
        self.assertGreaterEqual(len(list(f.user.parent.glob("binds.user.json.bak-*"))), 3)

    def test_list(self):
        f = Fx(); d = f.run("list")
        self.assertTrue(d["ok"]); self.assertEqual(len(d["binds"]), 3); self.assertEqual(d["conflictCount"], 0)

    def test_set_normalizes_and_saves(self):
        f = Fx()
        pass
        r = f.run("set", "a.one", "ALT + SUPER + x")
        self.assertTrue(r["ok"], r)
        self.assertEqual(f.saved()["a.one"], {"key": "SUPER + ALT + X"})

    def test_conflict_with_catalog_and_external(self):
        f = Fx()
        self.assertFalse(f.run("set", "a.one", "SUPER + SHIFT + b")["ok"])
        self.assertFalse(f.run("set", "a.one", "SUPER + T")["ok"])
        self.assertFalse(f.user.exists())

    def test_invalid_keys(self):
        f = Fx()
        for bad in ["", "SUPER", "Tab", "A", "space", "code:49", "FOO + A", "SUPER + shift", "SUPER + a b", "SUPER + $"]:
            self.assertFalse(f.run("set", "a.one", bad)["ok"], bad)
        self.assertFalse(f.run("set", "nope", "SUPER + X")["ok"])

    def test_default_key_removes_override_and_reset(self):
        f = Fx()
        f.run("set", "a.one", "SUPER + X")
        self.assertTrue(f.run("set", "a.one", "super + a")["ok"])
        self.assertNotIn("a.one", f.saved())
        f.run("disable", "a.two"); self.assertEqual(f.saved()["a.two"], {"enabled": False})
        f.run("reset", "a.two"); self.assertEqual(f.saved(), {})
        f.run("set", "a.one", "SUPER + X"); f.run("reset-all"); self.assertEqual(f.saved(), {})

    def test_backup_and_no_leftovers(self):
        f = Fx()
        f.run("set", "a.one", "SUPER + X"); f.run("set", "a.one", "SUPER + Y")
        names = [p.name for p in f.user.parent.iterdir()]
        self.assertTrue(any(".bak-" in n for n in names))
        self.assertFalse(any(n.endswith(".new") for n in names))

    def test_corrupt_user_file_is_treated_as_empty(self):
        f = Fx(); f.user.write_text("{nope")
        self.assertTrue(f.run("list")["ok"])
        self.assertTrue(f.run("set", "a.one", "SUPER + X")["ok"])

    def test_custom_add_edit_remove(self):
        f = Fx()
        r = f.run("add", "Notas", "super + alt + n", "kitty -e nvim ~/notas.md")
        self.assertTrue(r["ok"], r)
        row = [b for b in r["binds"] if b.get("custom")][0]
        self.assertEqual((row["id"], row["key"], row["group"], row["pending"]), ("custom.1", "SUPER + ALT + N", "Personalizados", True))
        self.assertFalse(f.run("add", "Otro", "SUPER + A", "true")["ok"])          # clashes with built-in
        self.assertFalse(f.run("add", "", "SUPER + K", "true")["ok"])               # empty label
        self.assertFalse(f.run("add", "X", "SUPER + K", "a\nb")["ok"])             # multi-line command
        self.assertFalse(f.run("add", "X", "SUPER + K", "a\tb")["ok"])             # control characters
        self.assertFalse(f.run("set", "a.one", "SUPER + ALT + N")["ok"])            # built-in clashes with custom
        r = f.run("edit", "custom.1", "Notas rápidas", "SUPER + ALT + M", "echo 'a, b'")
        self.assertTrue(r["ok"], r)
        self.assertEqual(f.saved_all()["custom"][0]["cmd"], "echo 'a, b'")
        self.assertFalse(f.run("edit", "a.one", "x", "SUPER + K", "y")["ok"])       # built-ins are not custom
        self.assertFalse(f.run("remove", "a.one")["ok"])
        self.assertTrue(f.run("remove", "custom.1")["ok"])
        self.assertNotIn("custom", f.saved_all())

    def test_enable_restores_chosen_key(self):
        f = Fx()
        f.run("set", "a.one", "SUPER + X"); f.run("disable", "a.one")
        self.assertEqual(f.saved()["a.one"], {"key": "SUPER + X", "enabled": False})
        self.assertTrue(f.run("enable", "a.one")["ok"])
        self.assertEqual(f.saved()["a.one"], {"key": "SUPER + X"})

    def test_undo_steps_back(self):
        f = Fx()
        self.assertFalse(f.run("undo")["ok"])
        f.run("set", "a.one", "SUPER + X"); f.run("set", "a.one", "SUPER + Y")
        self.assertTrue(f.run("undo")["ok"]); self.assertEqual(f.saved()["a.one"], {"key": "SUPER + X"})
        self.assertTrue(f.run("undo")["ok"]); self.assertEqual(f.saved(), {})
        self.assertFalse(f.run("list")["canUndo"])

    def test_external_rows_are_read_only(self):
        f = Fx(); d = f.run("list")
        ext = d["external"]
        self.assertEqual(len(ext), 1); self.assertEqual(ext[0]["key"], "SUPER + T"); self.assertTrue(ext[0]["external"])
        self.assertFalse(f.run("set", ext[0]["id"], "SUPER + K")["ok"])

    def test_failed_apply_rolls_back(self):
        f = Fx()
        env = dict(f.env); env.pop("ISLA_NO_RELOAD")
        (f.user.parent / "hyprctl").write_text('#!/usr/bin/env python3\nimport sys,json\nprint("[]" if "binds" in sys.argv else "")\n')
        f.env = env
        f.user.write_text(json.dumps({"version": 1, "binds": {"a.two": {"key": "SUPER + Y"}}}))
        r = f.run("set", "a.one", "SUPER + X")
        self.assertFalse(r["ok"], r)
        self.assertEqual(f.saved(), {"a.two": {"key": "SUPER + Y"}})

    def _fail_apply(self, f):
        env = dict(f.env); env.pop("ISLA_NO_RELOAD"); f.env = env
        (f.user.parent / "hyprctl").write_text('#!/usr/bin/env python3\nimport sys,json\nprint("[]" if "binds" in sys.argv else "")\n')

    def test_failed_apply_restores_exact_bytes(self):
        f = Fx()
        original = b'{"version": 1, "binds": {"a.two": {"key": "SUPER + Y"}}, "note": "mine"}\n'
        f.user.write_bytes(original)
        self._fail_apply(f)
        self.assertFalse(f.run("set", "a.one", "SUPER + X")["ok"])
        self.assertEqual(f.user.read_bytes(), original)
        self.assertEqual(list(f.user.parent.glob("binds.user.json.bak-*")), [])

    def test_failed_undo_keeps_backup(self):
        f = Fx()
        f.run("set", "a.one", "SUPER + X")
        self._fail_apply(f)
        self.assertFalse(f.run("undo")["ok"])
        self.assertEqual(f.saved()["a.one"], {"key": "SUPER + X"})
        self.assertEqual(len(list(f.user.parent.glob("binds.user.json.bak-*"))), 1)

    def test_reset_all_refuses_custom_clash(self):
        f = Fx()
        cat = json.loads((f.user.parent / "cat.json").read_text())
        cat["binds"][0]["key"] = "SUPER + X"
        (f.user.parent / "cat.json").write_text(json.dumps(cat))
        f.user.write_text(json.dumps({"version": 1, "binds": {"a.one": {"key": "SUPER + X"}}}))
        self.assertTrue(f.run("add", "Notas", "SUPER + A", "true")["ok"])
        before = f.user.read_bytes()
        self.assertFalse(f.run("reset-all")["ok"])
        self.assertEqual(f.user.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
