#!/usr/bin/env python3
"""Private metadata parity, permissions, Python locking and exec fallback."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
PYTHON = ROOT / "bar/services/clipboard_library.py"


def fixture(count=1):
    return {"version": 1, "collections": [{"id": "c-" + "1" * 32, "name": "Pruebas á 中文"}],
            "entries": [{"id": "s-" + f"{i:032x}", "text": "Synthetic\ntext\0 á🙂 " + str(i),
                         "preview": "Synthetic", "isImage": bool(i % 2),
                         "collectionId": "c-" + "1" * 32, "digest": "a" * 64}
                        for i in range(count)], "unknown": {"array": [1, None, True, "extra"]}}


class ClipboardListTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="isla-clipboard-list-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "library"
        self.path.mkdir()
        self.env = {**os.environ, "ISLA_CLIPBOARD_LIBRARY": str(self.path)}

    def write(self, data):
        (self.path / "library.json").write_text(json.dumps(data), encoding="utf-8")
        for item in data.get("entries", []) if isinstance(data, dict) else []:
            if isinstance(item, dict) and isinstance(item.get("id"), str) and len(item["id"]) == 34:
                (self.path / (item["id"] + ".bin")).write_bytes(b"private synthetic payload")

    def call(self, native=True, fallback=False, env=None):
        cmd = [str(BINARY), "list"] if native else [sys.executable, str(PYTHON), "list"]
        if fallback:
            cmd += ["--fallback", str(PYTHON)]
        result = subprocess.run(cmd, env=env or self.env, capture_output=True, timeout=5)
        self.assertEqual(result.stderr, b"")
        return result.returncode, json.loads(result.stdout)

    def parity(self, good=True, fallback=False):
        python = self.call(False)
        rust = self.call(True, fallback)
        self.assertEqual(python[0], rust[0], (python, rust))
        self.assertEqual(rust[1]["ok"], good, rust)
        if good:
            self.assertEqual(json.dumps(python[1], sort_keys=True), json.dumps(rust[1], sort_keys=True))

    def test_valid_metadata_unknown_fields_and_no_payload_mutation(self):
        for count in (0, 1, 100):
            data = fixture(count)
            data["unknown"]["integer"] = 10 ** 100
            self.write(data)
            before = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.path.glob("*.bin")}
            metadata = (self.path / "library.json").read_bytes()
            self.parity()
            self.assertEqual((self.path / "library.json").read_bytes(), metadata)
            self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.path.glob("*.bin")})
        for version in (True, 1.0, 1):
            data = fixture()
            data["version"] = version
            data["entries"][0].pop("collectionId")
            self.write(data)
            self.parity()

    def test_invalid_metadata_never_succeeds(self):
        cases = [[], {}, {"version": 2, "collections": [], "entries": []}]
        for key, value in (("id", "../bad"), ("id", "s-" + "A" * 32), ("text", 42),
                           ("preview", None), ("isImage", 1), ("collectionId", "c-" + "0" * 32),
                           ("digest", "not a digest"), ("collectionId", None)):
            data = fixture(); data["entries"][0][key] = value; cases.append(data)
        for key in ("id", "text", "preview", "isImage"):
            data = fixture(); data["entries"][0].pop(key); cases.append(data)
        for name in ("", " \t\r\n", "\x1c\x1d\x1e\x1f"):
            data = fixture(); data["collections"][0]["name"] = name; cases.append(data)
        data = fixture(); data["entries"] *= 2; cases.append(data)
        data = fixture(); data["collections"] *= 2; cases.append(data)
        data = fixture(); data["entries"] = [None]; cases.append(data)
        for data in cases:
            with self.subTest(data=data):
                self.write(data)
                self.parity(False)

    def test_missing_snapshots_directories_and_symlinks(self):
        self.write(fixture())
        payload = next(self.path.glob("*.bin"))
        payload.unlink()
        self.parity(False)
        payload.mkdir()
        self.parity(False)
        payload.rmdir()
        outside = Path(self.tmp.name) / "outside"
        outside.write_text("must stay private")
        payload.symlink_to(outside)
        self.parity(False)
        payload.unlink()
        self.write(fixture())
        metadata = self.path / "library.json"
        metadata.unlink(); metadata.symlink_to(outside)
        self.parity(False)
        self.assertEqual(outside.read_text(), "must stay private")

    def test_permissions_empty_location_and_lock_symlink(self):
        self.parity()
        self.assertFalse((self.path / "library.json").exists())
        self.write(fixture())
        self.path.chmod(0o777)
        (self.path / "library.json").chmod(0o666)
        (self.path / ".lock").chmod(0o666)
        self.call()
        for p, mode in ((self.path, 0o700), (self.path / "library.json", 0o600), (self.path / ".lock", 0o600)):
            self.assertEqual(p.stat().st_mode & 0o777, mode)
        lock = self.path / ".lock"
        lock.unlink(); lock.symlink_to(self.path / "library.json")
        self.parity(False)
        alias = Path(self.tmp.name) / "alias"
        alias.symlink_to(self.path, target_is_directory=True)
        self.assertFalse(self.call(env={**self.env, "ISLA_CLIPBOARD_LIBRARY": str(alias)})[1]["ok"])
        self.assertFalse(self.call(env={**self.env, "ISLA_CLIPBOARD_LIBRARY": "relative"})[1]["ok"])

    def test_python_flock_interop_and_cancellation_without_children(self):
        self.write(fixture())
        with (self.path / ".lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            proc = subprocess.Popen([str(BINARY), "list"], env=self.env, stdout=subprocess.PIPE)
            try:
                time.sleep(.05)
                self.assertIsNone(proc.poll(), "did not honor Python lock")
                children = Path(f"/proc/{proc.pid}/task/{proc.pid}/children").read_text().strip()
                self.assertEqual(children, "")
                fcntl.flock(lock, fcntl.LOCK_UN)
                output, _ = proc.communicate(timeout=3)
                self.assertEqual(json.loads(output)["data"], fixture())
            finally:
                if proc.poll() is None: proc.kill()
                proc.wait(timeout=3)
                proc.stdout.close()
            fcntl.flock(lock, fcntl.LOCK_EX)
            proc = subprocess.Popen([str(BINARY), "list"], env=self.env, stdout=subprocess.PIPE)
            try:
                time.sleep(.05)
                proc.terminate()
                proc.wait(timeout=1)
                self.assertEqual(proc.returncode, -signal.SIGTERM)
            finally:
                if proc.poll() is None: proc.kill()
                proc.wait(timeout=3)
                proc.stdout.close()

    def test_parser_compatibility_falls_back_without_deadlock(self):
        nested = []
        for _ in range(200): nested = [nested]
        for extra in (float("nan"), float("inf"), nested):
            data = fixture(); data["unknown"] = extra; self.write(data)
            self.parity(fallback=True)
        for extra in ({"$serde_json::private::Number": "123"}, {"quote\"key": "must stay a map"}):
            data = fixture(); data["unknown"] = extra; self.write(data)
            self.parity(fallback=True)
        fake = Path(self.tmp.name) / "fallback.py"
        fake.write_text("import json,os,sys; print(json.dumps({'pid':os.getpid(),'args':sys.argv[1:]}))")
        self.write({**fixture(), "unknown": float("nan")})
        proc = subprocess.Popen([str(BINARY), "list", "--fallback", str(fake)], env=self.env, stdout=subprocess.PIPE)
        output, _ = proc.communicate(timeout=3)
        self.assertEqual(json.loads(output), {"pid": proc.pid, "args": ["list"]})

    def test_bad_arguments_and_broken_stdout_do_not_panic(self):
        for args in ([], ["save"], ["list", "extra"], ["list", "--fallback"]):
            result = subprocess.run([str(BINARY), *args], env=self.env, capture_output=True, timeout=3)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(json.loads(result.stdout)["ok"])
            self.assertEqual(result.stderr, b"")
        self.write(fixture(1000))
        process = subprocess.Popen([str(BINARY), "list"], env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        process.stdout.close()
        process.wait(timeout=3)
        self.assertEqual(process.returncode, 1)
        self.assertEqual(process.stderr.read(), b"")
        process.stderr.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    BINARY = args.binary.resolve()
    unittest.main(argv=[__file__, *remaining])
