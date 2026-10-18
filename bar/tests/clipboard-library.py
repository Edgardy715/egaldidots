#!/usr/bin/env python3
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "services/clipboard_library.py"
spec = importlib.util.spec_from_file_location("clipboard_library", MODULE)
lib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lib)


class LibraryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "library"
        self.env = patch.dict(os.environ, {"ISLA_CLIPBOARD_LIBRARY": str(self.path)})
        self.env.start()
        self.addCleanup(self.env.stop)

    def save(self, source, payload, image=False, collection_id=None):
        with patch.object(lib.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, payload)):
            args = ["save", source, "1" if image else "0", "" if image else "visible", "[[ binary data 3x2 ]]" if image else "visible"]
            if collection_id is not None:
                args.append(collection_id)
            item_id = lib.dispatch(args)["id"]
        return item_id

    def test_snapshots_survive_history_wipe_and_copy_exact_bytes(self):
        text = b"nul\x00and\nutf8 \xc3\xa1"
        image = b"\x89PNG\r\n\x1a\n\x00\xff"
        first = self.save("1", text)
        second = self.save("2", image, True)
        self.assertEqual(lib.dispatch(["list"])["entries"][1]["text"], text.decode("utf-8"))
        self.assertEqual(lib.read_snapshot(self.path, first), text)
        self.assertEqual(lib.read_snapshot(self.path, second), image)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.path / "library.json").stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(lib.data_path(self.path, first).stat().st_mode), 0o600)
        with patch.object(lib.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as command:
            lib.dispatch(["copy", first])
        self.assertEqual(command.call_args.args[0], ["wl-copy"])
        self.assertEqual(command.call_args.kwargs["input"], text)
        self.assertEqual(len(lib.dispatch(["list"])["entries"]), 2)

    def test_collections_and_deletion_preserves_items(self):
        item_id = self.save("4", b"memo")
        collection = lib.dispatch(["create", " Work "])["id"]
        lib.dispatch(["rename", collection, "Notes"])
        lib.dispatch(["move", item_id, collection])
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], collection)
        lib.dispatch(["delete", collection])
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], "")
        self.assertEqual(lib.read_snapshot(self.path, item_id), b"memo")
        lib.dispatch(["remove", item_id])
        self.assertEqual(lib.dispatch(["list"])["entries"], [])
        self.assertFalse(lib.data_path(self.path, item_id).exists())

    def test_bad_ids_metadata_and_write_error_preserve_data(self):
        item_id = self.save("8", b"keep")
        with self.assertRaises(ValueError):
            lib.dispatch(["remove", "../library.json"])
        with self.assertRaises(ValueError):
            lib.dispatch(["move", item_id, "../../bad"])
        with patch.object(lib, "commit", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                lib.dispatch(["remove", item_id])
        self.assertEqual(lib.read_snapshot(self.path, item_id), b"keep")
        self.assertEqual(len(lib.dispatch(["list"])["entries"]), 1)
        original = (self.path / "library.json").read_bytes()
        (self.path / "library.json").write_text('{"version":999}', encoding="utf-8")
        with self.assertRaises(ValueError):
            lib.dispatch(["create", "must not overwrite"])
        self.assertEqual(json.loads((self.path / "library.json").read_text())["version"], 999)
        (self.path / "library.json").write_bytes(original)
        self.assertEqual(len(lib.dispatch(["list"])["entries"]), 1)

    def test_duplicate_collection_names_reject_without_changing_data(self):
        first = lib.dispatch(["create", "Proyectos"])["id"]
        second = lib.dispatch(["create", "Ideas"])["id"]
        with self.assertRaisesRegex(ValueError, "collection_exists"):
            lib.dispatch(["create", " proyectos "])
        with self.assertRaisesRegex(ValueError, "collection_exists"):
            lib.dispatch(["rename", second, "PROYECTOS"])
        lib.dispatch(["rename", first, "PROYECTOS"])
        self.assertEqual([c["name"] for c in lib.dispatch(["list"])["collections"]], ["PROYECTOS", "Ideas"])

    def test_concurrent_writers_keep_every_snapshot(self):
        fake = Path(self.temp.name) / "cliphist"
        fake.write_text("#!/bin/sh\nprintf 'full untruncated text:%s' \"$2\"\n", encoding="utf-8")
        fake.chmod(0o700)
        env = dict(os.environ, PATH=self.temp.name + os.pathsep + os.environ["PATH"])
        children = [subprocess.Popen(["python3", str(MODULE), "save", str(i), "0", "truncated", "truncated"], env=env, stdout=subprocess.PIPE) for i in range(8)]
        for child in children:
            output, _ = child.communicate(timeout=10)
            self.assertEqual(child.returncode, 0, output)
        items = lib.dispatch(["list"])["entries"]
        self.assertEqual(len(items), 8)
        self.assertEqual({item["text"] for item in items}, {f"full untruncated text:{i}" for i in range(8)})

    def test_save_keeps_payload_if_commit_reports_post_replace_error(self):
        actual_commit = lib.commit
        def fail_after_replace(path, data):
            actual_commit(path, data)
            raise OSError("directory fsync failed")
        with patch.object(lib.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"valuable")):
            with patch.object(lib, "commit", side_effect=fail_after_replace):
                with self.assertRaises(OSError):
                    lib.dispatch(["save", "9", "0", "short", "short"])
        item = lib.dispatch(["list"])["entries"][0]
        self.assertEqual(lib.read_snapshot(self.path, item["id"]), b"valuable")

    def test_identical_snapshot_reuses_saved_item(self):
        original = self.save("1", b"exact content")
        duplicate = self.save("42", b"exact content")
        self.assertEqual(duplicate, original)
        self.assertEqual(len(lib.dispatch(["list"])["entries"]), 1)

    def test_save_assigns_collection_atomically_and_dedup_moves_only_when_requested(self):
        first = lib.dispatch(["create", "First"])["id"]
        second = lib.dispatch(["create", "Second"])["id"]
        item_id = self.save("1", b"same content", collection_id=first)
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], first)

        self.assertEqual(self.save("2", b"same content"), item_id)
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], first)
        self.assertEqual(self.save("3", b"same content", collection_id=second), item_id)
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], second)
        self.save("4", b"same content", collection_id="")
        self.assertEqual(lib.dispatch(["list"])["entries"][0]["collectionId"], "")
        self.assertEqual(len(lib.dispatch(["list"])["entries"]), 1)

    def test_save_rejects_unknown_collection_before_decoding(self):
        with patch.object(lib.subprocess, "run") as command:
            with self.assertRaises(ValueError):
                lib.dispatch(["save", "1", "0", "short", "short", "c-" + "0" * 32])
            command.assert_not_called()

        collection = lib.dispatch(["create", "Known"])["id"]
        lib.dispatch(["delete", collection])
        with patch.object(lib.subprocess, "run") as command:
            with self.assertRaises(ValueError):
                lib.dispatch(["save", "1", "0", "short", "short", collection])
            command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
