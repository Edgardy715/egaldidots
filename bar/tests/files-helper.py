#!/usr/bin/env python3
"""Offline tests for services/files_helper.py (temp dirs only, HOME/XDG redirected)."""
import errno
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "services/files_helper.py"
spec = importlib.util.spec_from_file_location("files_helper", MODULE)
fh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fh)


class Base(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.home / ".local/share"),
               "XDG_CACHE_HOME": str(self.home / ".cache")}
        patcher = patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        fh.CANCEL.clear()
        self.src = self.root / "src"
        self.dst = self.root / "dst"
        self.src.mkdir()
        self.dst.mkdir()
        self.events = []

    def emit(self, ev):
        self.events.append(ev)

    def errors(self):
        return [e for e in self.events if e["event"] == "item_error"]

    def req(self, sources, conflict=None, dest=None):
        r = {"sources": [str(s) for s in sources], "dest": str(dest or self.dst)}
        if conflict:
            r["conflict"] = conflict
        return r

    def write(self, path, text="x"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path


class CopyTest(Base):
    def test_copy_tree_preserves_symlinks(self):
        tree = self.src / "tree"
        self.write(tree / "sub/f.txt", "hello")
        os.symlink("f.txt", tree / "sub/link")
        os.symlink("/nonexistent/target", tree / "dangling")
        done = fh.run_copy(self.req([tree]), self.emit)
        self.assertTrue(done["ok"])
        self.assertIsNone(done["undo"])
        out = self.dst / "tree"
        self.assertEqual((out / "sub/f.txt").read_text(), "hello")
        self.assertTrue((out / "sub/link").is_symlink())
        self.assertEqual(os.readlink(out / "sub/link"), "f.txt")
        self.assertTrue((out / "dangling").is_symlink())
        self.assertEqual(os.readlink(out / "dangling"), "/nonexistent/target")

    def test_keepboth_names_a_2_txt(self):
        a = self.write(self.src / "a.txt", "new")
        self.write(self.dst / "a.txt", "old")
        fh.run_copy(self.req([a], "keepboth"), self.emit)
        self.assertEqual((self.dst / "a.txt").read_text(), "old")
        self.assertEqual((self.dst / "a (2).txt").read_text(), "new")
        self.assertEqual(fh.unique_name(self.dst, "a.txt"), "a (3).txt")
        self.assertEqual(fh.unique_name(self.dst, "fresh.txt"), "fresh.txt")

    def test_paste_in_same_folder_never_overwrites(self):
        a = self.write(self.src / "a.txt", "orig")
        for policy in ("overwrite", "skip", "keepboth", None):
            fh.run_copy(self.req([a], policy, dest=self.src), self.emit)
            self.assertEqual(a.read_text(), "orig")
        self.assertTrue((self.src / "a (2).txt").exists())

    def test_skip_leaves_destination_untouched(self):
        a = self.write(self.src / "a.txt", "new")
        self.write(self.dst / "a.txt", "old")
        done = fh.run_copy(self.req([a], "skip"), self.emit)
        self.assertTrue(done["ok"])
        self.assertEqual((self.dst / "a.txt").read_text(), "old")
        self.assertEqual(sorted(os.listdir(self.dst)), ["a.txt"])

    def test_overwrite_requires_explicit_policy(self):
        a = self.write(self.src / "a.txt", "new")
        self.write(self.dst / "a.txt", "old")
        fh.run_copy(self.req([a]), self.emit)
        self.assertEqual((self.dst / "a.txt").read_text(), "old")
        fh.run_copy(self.req([a], "bogus"), self.emit)
        self.assertEqual((self.dst / "a.txt").read_text(), "old")
        fh.run_copy(self.req([a], "overwrite"), self.emit)
        self.assertEqual((self.dst / "a.txt").read_text(), "new")

    def test_copy_into_itself_rejected(self):
        d = self.src / "d"
        self.write(d / "f.txt")
        (d / "child").mkdir()
        before = sorted(str(p) for p in self.root.rglob("*"))
        for target in (d, d / "child"):
            done = fh.run_copy(self.req([d], "keepboth", dest=target), self.emit)
            self.assertFalse(done["ok"])
        self.assertEqual(sorted(str(p) for p in self.root.rglob("*")), before)
        self.assertTrue(self.errors())

    def test_progress_monotonic(self):
        for i in range(5):
            (self.src / f"f{i}").write_bytes(b"z" * (1024 * 1024 * 2 + i))
        fh.run_copy(self.req(sorted(self.src.iterdir())), self.emit)
        prog = [e for e in self.events if e["event"] == "progress"]
        self.assertTrue(prog)
        dones = [p["done"] for p in prog]
        self.assertEqual(dones, sorted(dones))
        self.assertTrue(all(p["done"] <= p["total"] for p in prog))
        self.assertEqual(prog[-1]["done"], prog[-1]["total"])
        self.assertTrue(all(isinstance(p["current"], str) for p in prog))

    def test_unreadable_item_reported_rest_continues(self):
        bad = self.write(self.src / "bad.txt", "secret")
        good = self.write(self.src / "good.txt", "fine")
        os.chmod(bad, 0)
        self.addCleanup(os.chmod, bad, 0o600)
        if os.access(bad, os.R_OK):
            self.skipTest("running with privileges that bypass permissions")
        done = fh.run_copy(self.req([bad, good]), self.emit)
        self.assertFalse(done["ok"])
        self.assertEqual([e["path"] for e in self.errors()], [str(bad)])
        self.assertEqual((self.dst / "good.txt").read_text(), "fine")
        self.assertFalse((self.dst / "bad.txt").exists())

    def test_odd_names(self):
        names = ["a#b%20 c?.txt", "-rf", "x\ny", "ñ😀.txt"]
        paths = [self.write(self.src / n, n) for n in names]
        os.symlink("/nope", self.src / "broken")
        paths.append(self.src / "broken")
        done = fh.run_copy(self.req(paths), self.emit)
        self.assertTrue(done["ok"], self.errors())
        for n in names:
            self.assertEqual((self.dst / n).read_text(), n)
        self.assertTrue((self.dst / "broken").is_symlink())
        self.assertEqual(sorted(fh.plan_conflicts([str(p) for p in paths], str(self.dst))), sorted(names + ["broken"]))
        # trash/restore with the same odd names
        done = fh.run_trash({"paths": [str(p) for p in paths]}, self.emit)
        self.assertTrue(done["ok"], self.errors())
        for n in names + ["broken"]:
            self.assertFalse(os.path.lexists(self.src / n))
        fh.run_restore({"entries": done["undo"]["entries"]}, self.emit)
        for n in names:
            self.assertEqual((self.src / n).read_text(), n)
        self.assertTrue((self.src / "broken").is_symlink())

    def test_relative_paths_rejected(self):
        a = self.write(self.src / "a.txt")
        done = fh.run_copy({"sources": ["a.txt"], "dest": str(self.dst)}, self.emit)
        self.assertFalse(done["ok"])
        done = fh.run_copy({"sources": [str(a)], "dest": "rel"}, self.emit)
        self.assertFalse(done["ok"])
        self.assertEqual(os.listdir(self.dst), [])

    def test_dot_components_rejected(self):
        for bad in (str(self.src) + "/.", str(self.src) + "/.."):
            done = fh.run_copy({"sources": [bad], "dest": str(self.dst)}, self.emit)
            self.assertFalse(done["ok"], bad)
        self.assertEqual(os.listdir(self.dst), [])

    def test_plan_conflicts_ignores_source_folder(self):
        a = self.write(self.src / "a.txt")
        self.assertEqual(fh.plan_conflicts([str(a)], str(self.src)), [])

    def test_plan_conflicts(self):
        a = self.write(self.src / "a.txt")
        b = self.write(self.src / "b.txt")
        self.write(self.dst / "b.txt")
        self.assertEqual(fh.plan_conflicts([str(a), str(b)], str(self.dst)), ["b.txt"])


class NameTest(Base):
    def test_require_name(self):
        self.assertEqual(fh.require_name("v1..2.txt"), "v1..2.txt")
        for bad in ("..", ".", "a/b", "", "a\0b"):
            with self.assertRaises(fh.Rejected):
                fh.require_name(bad)
        done = fh.run_mkdir({"parent": str(self.dst), "name": "v1..2"}, self.emit)
        self.assertTrue(done["ok"])
        done = fh.run_mkdir({"parent": str(self.dst), "name": "a/b"}, self.emit)
        self.assertFalse(done["ok"])


class MoveTest(Base):
    def test_move_across_same_fs_is_rename(self):
        a = self.write(self.src / "a.txt", "data")
        inode = a.stat().st_ino
        done = fh.run_move(self.req([a]), self.emit)
        self.assertTrue(done["ok"])
        self.assertFalse(a.exists())
        self.assertEqual((self.dst / "a.txt").stat().st_ino, inode)
        self.assertEqual(done["undo"], {"op": "moveback", "pairs": [{"from": str(self.dst / "a.txt"), "to": str(a)}]})

    def test_move_cross_fs_copies_then_deletes_source(self):
        d = self.src / "d"
        self.write(d / "f.txt", "data")
        real = os.rename
        def fake(a, b, *args, **kw):
            if str(a) == str(d):
                raise OSError(errno.EXDEV, "cross-device")
            return real(a, b, *args, **kw)
        with patch.object(fh.os, "rename", side_effect=fake):
            done = fh.run_move(self.req([d]), self.emit)
        self.assertTrue(done["ok"], self.errors())
        self.assertFalse(d.exists())
        self.assertEqual((self.dst / "d/f.txt").read_text(), "data")

    def test_move_cross_fs_keeps_source_on_failure(self):
        d = self.src / "d"
        self.write(d / "f.txt", "data")
        bad = self.write(d / "bad.txt", "secret")
        os.chmod(bad, 0)
        self.addCleanup(os.chmod, bad, 0o600)
        if os.access(bad, os.R_OK):
            self.skipTest("running with privileges that bypass permissions")
        real = os.rename
        def fake(a, b, *args, **kw):
            if str(a) == str(d):
                raise OSError(errno.EXDEV, "cross-device")
            return real(a, b, *args, **kw)
        with patch.object(fh.os, "rename", side_effect=fake):
            done = fh.run_move(self.req([d]), self.emit)
        self.assertFalse(done["ok"])
        self.assertTrue(bad.exists())
        self.assertEqual((d / "f.txt").read_text(), "data")

    def test_moveback_restores_original_locations(self):
        a = self.write(self.src / "a.txt", "data")
        done = fh.run_move(self.req([a]), self.emit)
        back = fh.run_moveback({"pairs": done["undo"]["pairs"]}, self.emit)
        self.assertTrue(back["ok"])
        self.assertEqual(a.read_text(), "data")
        self.assertFalse((self.dst / "a.txt").exists())
        # never overwrites an existing original
        fh.run_move(self.req([a]), self.emit)
        self.write(a, "other")
        back = fh.run_moveback({"pairs": [{"from": str(self.dst / "a.txt"), "to": str(a)}]}, self.emit)
        self.assertFalse(back["ok"])
        self.assertEqual(a.read_text(), "other")
        self.assertTrue((self.dst / "a.txt").exists())

    def test_move_cross_fs_keeps_files_created_during_copy(self):
        d = self.src / "d"
        self.write(d / "f.txt", "data")
        real = os.rename
        def fake(a, b, *args, **kw):
            if str(a) == str(d):
                raise OSError(errno.EXDEV, "cross-device")
            return real(a, b, *args, **kw)
        real_copy = fh.copy_file
        def copy_and_intrude(src, dst, ctx, overwrite):
            real_copy(src, dst, ctx, overwrite)
            (d / "late.txt").write_text("appeared meanwhile")
        with patch.object(fh.os, "rename", side_effect=fake), patch.object(fh, "copy_file", copy_and_intrude):
            done = fh.run_move(self.req([d]), self.emit)
        self.assertFalse(done["ok"])
        self.assertEqual((d / "late.txt").read_text(), "appeared meanwhile")
        self.assertFalse((d / "f.txt").exists())
        self.assertEqual((self.dst / "d/f.txt").read_text(), "data")
        self.assertTrue(self.errors())

    def test_move_dir_over_nonempty_dir_with_overwrite_merges(self):
        self.write(self.src / "d/new.txt", "new")
        self.write(self.src / "d/both.txt", "from src")
        self.write(self.dst / "d/old.txt", "old")
        self.write(self.dst / "d/both.txt", "from dst")
        done = fh.run_move(self.req([self.src / "d"], "overwrite"), self.emit)
        self.assertTrue(done["ok"], self.errors())
        self.assertEqual((self.dst / "d/old.txt").read_text(), "old")
        self.assertEqual((self.dst / "d/new.txt").read_text(), "new")
        self.assertEqual((self.dst / "d/both.txt").read_text(), "from src")
        self.assertFalse((self.src / "d").exists())
        self.assertIsNone(done["undo"])

    def test_move_into_itself_rejected(self):
        d = self.src / "d"
        (d / "c").mkdir(parents=True)
        done = fh.run_move(self.req([d], dest=d / "c"), self.emit)
        self.assertFalse(done["ok"])
        self.assertTrue(d.exists())

    def test_move_skip_and_keepboth(self):
        a = self.write(self.src / "a.txt", "new")
        self.write(self.dst / "a.txt", "old")
        fh.run_move(self.req([a], "skip"), self.emit)
        self.assertTrue(a.exists())
        self.assertEqual((self.dst / "a.txt").read_text(), "old")
        fh.run_move(self.req([a], "keepboth"), self.emit)
        self.assertFalse(a.exists())
        self.assertEqual((self.dst / "a (2).txt").read_text(), "new")


class TrashTest(Base):
    def trash_dir(self):
        return self.home / ".local/share/Trash"

    def test_trash_writes_trashinfo_and_restore_roundtrips(self):
        a = self.write(self.src / "my file#1.txt", "data")
        done = fh.run_trash({"paths": [str(a)]}, self.emit)
        self.assertTrue(done["ok"], self.errors())
        self.assertFalse(a.exists())
        entry = done["undo"]["entries"][0]
        self.assertEqual(done["undo"]["op"], "restore")
        self.assertEqual(entry["original"], str(a))
        trashed = Path(entry["trashed"])
        self.assertEqual(trashed.parent, self.trash_dir() / "files")
        info = self.trash_dir() / "info" / (trashed.name + ".trashinfo")
        text = info.read_text()
        self.assertTrue(text.startswith("[Trash Info]\n"))
        self.assertIn("Path=" + str(self.src) + "/my%20file%231.txt\n", text)
        self.assertRegex(text, r"DeletionDate=\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d")
        back = fh.run_restore({"entries": done["undo"]["entries"]}, self.emit)
        self.assertTrue(back["ok"])
        self.assertIsNone(back["undo"])
        self.assertEqual(a.read_text(), "data")
        self.assertFalse(trashed.exists())
        self.assertFalse(info.exists())

    def test_trash_same_name_gets_unique_entries(self):
        a = self.write(self.src / "x/a.txt", "1")
        b = self.write(self.src / "y/a.txt", "2")
        done = fh.run_trash({"paths": [str(a), str(b)]}, self.emit)
        names = {Path(e["trashed"]).name for e in done["undo"]["entries"]}
        self.assertEqual(len(names), 2)
        self.assertIn("a (2).txt", names)

    def test_restore_does_not_overwrite_existing(self):
        a = self.write(self.src / "a.txt", "trashed")
        done = fh.run_trash({"paths": [str(a)]}, self.emit)
        self.write(a, "new occupant")
        back = fh.run_restore({"entries": done["undo"]["entries"]}, self.emit)
        self.assertEqual(a.read_text(), "new occupant")
        restored = back["result"]
        self.assertEqual(len(restored), 1)
        self.assertEqual(Path(restored[0]).read_text(), "trashed")

    def test_trash_never_unlinks_when_trash_fails(self):
        a = self.write(self.src / "a.txt", "precious")
        with patch.object(fh.os, "rename", side_effect=OSError(errno.EIO, "boom")):
            done = fh.run_trash({"paths": [str(a)]}, self.emit)
        self.assertFalse(done["ok"])
        self.assertEqual(a.read_text(), "precious")
        self.assertTrue(self.errors())
        info = self.trash_dir() / "info"
        self.assertEqual(list(info.iterdir()) if info.exists() else [], [])

    def test_trash_other_fs_uses_gio_without_undo(self):
        a = self.write(self.src / "a.txt", "data")
        calls = []
        def fake_run(cmd, **kw):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0, "", "")
        with patch.object(fh, "same_device", return_value=False), patch.object(fh.subprocess, "run", fake_run):
            done = fh.run_trash({"paths": [str(a)]}, self.emit)
        self.assertTrue(done["ok"])
        self.assertIsNone(done["undo"])
        self.assertEqual(calls, [["gio", "trash", "--", str(a)]])
        self.assertTrue(a.exists())  # fake gio did nothing; helper itself never unlinks

    def test_trash_missing_path_reported(self):
        done = fh.run_trash({"paths": [str(self.src / "nope")]}, self.emit)
        self.assertFalse(done["ok"])
        self.assertTrue(self.errors())


class SmallOpsTest(Base):
    def test_rename(self):
        a = self.write(self.src / "a.txt", "data")
        done = fh.run_rename({"path": str(a), "name": "b.txt"}, self.emit)
        self.assertTrue(done["ok"])
        self.assertEqual(done["undo"], {"op": "rename", "path": str(self.src / "b.txt"), "name": "a.txt"})
        self.assertEqual((self.src / "b.txt").read_text(), "data")

    def test_rename_never_overwrites_and_rejects_bad_names(self):
        a = self.write(self.src / "a.txt", "A")
        self.write(self.src / "b.txt", "B")
        for name in ("b.txt", "x/y", "..", ".", "", "a\0b"):
            done = fh.run_rename({"path": str(a), "name": name}, self.emit)
            self.assertFalse(done["ok"], name)
        self.assertEqual(a.read_text(), "A")
        self.assertEqual((self.src / "b.txt").read_text(), "B")

    def test_mkdir(self):
        done = fh.run_mkdir({"parent": str(self.src), "name": "new dir"}, self.emit)
        self.assertTrue(done["ok"])
        self.assertIsNone(done["undo"])
        self.assertTrue((self.src / "new dir").is_dir())
        self.assertFalse(fh.run_mkdir({"parent": str(self.src), "name": "new dir"}, self.emit)["ok"])
        self.assertFalse(fh.run_mkdir({"parent": str(self.src), "name": "../up"}, self.emit)["ok"])
        self.assertFalse(fh.run_mkdir({"parent": "rel", "name": "x"}, self.emit)["ok"])

    def test_thumb_video_uses_freedesktop_cache(self):
        v = self.write(self.src / "a (2)&b+c.mp4", "fake")
        seen = []
        def fake_run(cmd, **kw):
            seen.append(cmd)
            Path(cmd[cmd.index("-o") + 1]).write_bytes(b"\x89PNG")
            return subprocess.CompletedProcess(cmd, 0, b"", b"")
        with patch.object(fh.subprocess, "run", fake_run):
            out = fh.thumb_video(str(v), 128)
            again = fh.thumb_video(str(v), 128)
        import hashlib, urllib.parse
        md5 = hashlib.md5(("file://" + urllib.parse.quote(str(v), safe="/!$&'()*+,;=:@~")).encode()).hexdigest()
        self.assertEqual(out, str(self.home / ".cache/thumbnails/normal" / (md5 + ".png")))
        self.assertEqual(again, out)
        self.assertEqual(len(seen), 1)  # second call served from cache
        self.assertEqual(seen[0][0], "ffmpegthumbnailer")
        self.assertIn("128", seen[0])
        with patch.object(fh.subprocess, "run", side_effect=FileNotFoundError):
            self.assertIsNone(fh.thumb_video(str(self.write(self.src / "o.mp4")), 256))
        self.assertIsNone(fh.thumb_video("relative.mp4", 128))


class CliTest(Base):
    def spawn(self, op, req):
        env = dict(os.environ)
        p = subprocess.Popen([sys.executable, str(MODULE), op], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             text=True, env=env)
        p.stdin.write(json.dumps(req) + "\n")
        p.stdin.flush()
        p.stdin.close()
        return p

    def drain(self, p):
        out = [json.loads(l) for l in p.stdout.read().splitlines()]
        p.stdout.close()
        p.wait(timeout=20)
        return out

    def test_cli_ndjson_roundtrip(self):
        a = self.write(self.src / "a.txt", "data")
        p = self.spawn("copy", self.req([a]))
        lines = self.drain(p)
        self.assertEqual(lines[-1]["event"], "done")
        self.assertTrue(lines[-1]["ok"])
        self.assertTrue(all(l["event"] in ("progress", "item_error", "done") for l in lines))
        self.assertEqual((self.dst / "a.txt").read_text(), "data")
        p = self.spawn("conflicts", self.req([a]))
        last = self.drain(p)[-1]
        self.assertEqual(last["result"], ["a.txt"])

    def test_cli_unknown_op_and_bad_json(self):
        p = self.spawn("explode", {})
        out = self.drain(p)
        self.assertFalse(out[-1]["ok"])

    def test_cancel_via_sigterm_emits_cancelled_done(self):
        for i in range(8):
            with open(self.src / f"big{i}", "wb") as fp:
                fp.truncate(32 * 1024 * 1024)
        p = self.spawn("copy", self.req(sorted(self.src.iterdir())))
        first = json.loads(p.stdout.readline())
        self.assertEqual(first["event"], "progress")
        p.send_signal(signal.SIGTERM)
        rest = self.drain(p)
        done = rest[-1]
        self.assertEqual(done["event"], "done")
        self.assertTrue(done["cancelled"])
        self.assertFalse(done["ok"])
        self.assertEqual(p.returncode, 0)
        # no half-written file is left behind: everything present has full size
        for f in self.dst.iterdir():
            self.assertEqual(f.stat().st_size, 32 * 1024 * 1024)
        self.assertLess(len(list(self.dst.iterdir())), 8)


if __name__ == "__main__":
    unittest.main()
