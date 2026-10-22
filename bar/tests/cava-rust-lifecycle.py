#!/usr/bin/env python3
"""Finite Rust CLI lifecycle checks with fake audio programs; no audio server access."""
import array
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
BINARY = Path(os.environ.get("ISLA_CAVA_RUST_BINARY", ROOT / "rust/cava-stream/target/release/isla-cava-stream"))
FAKE = r'''#!/usr/bin/env python3
import json, os, signal, sys, time
from pathlib import Path
work = Path(os.environ["ISLA_CAVA_LIFECYCLE"])
kind = Path(sys.argv[0]).name
fd = os.open(work / "children", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
os.write(fd, (json.dumps({"pid": os.getpid(), "kind": kind, "args": sys.argv[1:]}) + "\n").encode())
os.close(fd)
if kind == "pactl":
    if sys.argv[1:] == ["subscribe"] or os.environ.get("ISLA_TEST_BLOCK_QUERY"):
        while True:
            signal.pause()
    state = json.loads((work / "state").read_text())
    print(json.dumps(state[sys.argv[-1]]))
elif kind == "cava":
    config = Path(sys.argv[2]).read_text()
    fifo = next(line.split(" = ", 1)[1] for line in config.splitlines() if line.startswith("source = "))
    reader = os.open(fifo, os.O_RDONLY)
    os.set_blocking(reader, False)
    frame = (" ".join(["32768"] * 24) + "\n").encode()
    while True:
        try:
            os.read(reader, 65536)
        except BlockingIOError:
            pass
        os.write(1, frame * (1000 if os.environ.get("ISLA_TEST_BURST") else 1))
        if not os.environ.get("ISLA_TEST_BURST"):
            time.sleep(1 / 60)
elif kind == "parec":
    while True:
        os.write(1, b"\0" * 4096)
else:
    raise AssertionError(kind)
'''
STATE = {
    "clients": [{"index": 116, "properties": {"application.name": "isla-lifecycle-fixture"}}],
    "sink-inputs": [{"index": 117, "client": 116, "sink": 58, "corked": False}],
    "sinks": [{"index": 58, "monitor_source": "fixture.monitor"}],
}


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(") ")[1][0] != "Z"
    except FileNotFoundError:
        return False


def wait_for(condition, message, timeout=4):
    deadline = time.monotonic() + timeout
    while not condition():
        if time.monotonic() >= deadline:
            raise AssertionError(message)
        time.sleep(.01)


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.assertTrue(BINARY.is_file(), f"build the Rust release first: {BINARY}")
        self.temp = tempfile.TemporaryDirectory(prefix="isla-cava-rust-lifecycle-")
        self.work = Path(self.temp.name)
        for name in ("pactl", "cava", "parec"):
            path = self.work / name
            path.write_text(FAKE)
            path.chmod(0o755)
        (self.work / "state").write_text(json.dumps(STATE))
        self.env = dict(os.environ, PATH=str(self.work) + os.pathsep + os.environ["PATH"],
                        ISLA_CAVA_LIFECYCLE=str(self.work))
        self.processes = []
        self.orphan_roots = []

    def children(self):
        path = self.work / "children"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def start(self, **kwargs):
        proc = subprocess.Popen([str(BINARY), "--identity", "isla-lifecycle-fixture", "--parent", str(os.getpid())],
                                env=self.env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, **kwargs)
        self.processes.append(proc)
        return proc

    def capture_ready(self, proc):
        wait_for(lambda: proc.poll() is not None or any(c["kind"] == "parec" for c in self.children()),
                 "fake capture did not start")
        self.assertIsNone(proc.poll(), "Rust helper exited before capture")
        active = [c for c in self.children() if c["kind"] in ("cava", "parec") or c["args"] == ["subscribe"]]
        self.assertEqual({c["kind"] for c in active}, {"cava", "parec", "pactl"})
        self.assertTrue(all(alive(c["pid"]) for c in active))

    def children_gone(self):
        wait_for(lambda: all(not alive(c["pid"]) for c in self.children()), "audio/discovery child survived helper")

    def tearDown(self):
        try:
            for proc in self.processes:
                if proc.poll() is None:
                    proc.kill()
                proc.wait(timeout=3)
                if proc.stdout:
                    proc.stdout.close()
            for pid in self.orphan_roots + [c["pid"] for c in self.children()]:
                if alive(pid):
                    os.kill(pid, signal.SIGKILL)
        finally:
            self.temp.cleanup()

    def test_parent_mismatch_aborts_before_spawn(self):
        result = subprocess.run([str(BINARY), "--parent", str(os.getpid() + 1000000)], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(self.children(), [])

    def test_signals_cleanup_active_capture_and_subscription(self):
        for sig in (signal.SIGTERM, signal.SIGKILL):
            with self.subTest(signal=sig.name):
                (self.work / "children").unlink(missing_ok=True)
                proc = self.start()
                self.capture_ready(proc)
                proc.send_signal(sig)
                self.assertEqual(proc.wait(timeout=2), 0 if sig == signal.SIGTERM else -signal.SIGKILL)
                self.children_gone()

    def test_sigterm_cancels_inflight_snapshot(self):
        self.env["ISLA_TEST_BLOCK_QUERY"] = "1"
        proc = self.start()
        wait_for(lambda: len(self.children()) >= 2, "subscription and pending query missing")
        self.assertTrue(any(c["args"] != ["subscribe"] and alive(c["pid"]) for c in self.children()))
        started = time.monotonic()
        proc.terminate()
        self.assertEqual(proc.wait(timeout=1), 0)
        self.assertLess(time.monotonic() - started, 1)
        self.children_gone()

    def test_stdout_backpressure_then_sigterm_or_broken_pipe(self):
        self.env["ISLA_TEST_BURST"] = "1"
        for finish in ("sigterm", "broken-pipe"):
            with self.subTest(finish=finish):
                (self.work / "children").unlink(missing_ok=True)
                proc = self.start()
                capacity = fcntl.fcntl(proc.stdout, fcntl.F_SETPIPE_SZ, 4096)
                self.capture_ready(proc)
                def pipe_full():
                    available = array.array("i", [0])
                    fcntl.ioctl(proc.stdout, termios.FIONREAD, available, True)
                    # A frame write under PIPE_BUF must wait once less than one frame fits.
                    return available[0] >= capacity - 150
                wait_for(pipe_full, "stdout pipe did not reach backpressure")
                self.assertIsNone(proc.poll())
                if finish == "sigterm":
                    proc.terminate()
                else:
                    proc.stdout.close()
                self.assertEqual(proc.wait(timeout=2), 0)
                self.children_gone()

    def test_owner_death_stops_helper_and_children(self):
        code = """import os,signal,subprocess,sys
p=subprocess.Popen([sys.argv[1],'--identity','isla-lifecycle-fixture','--parent',str(os.getpid())],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
print(p.pid,flush=True)
while True: signal.pause()
"""
        owner = subprocess.Popen([sys.executable, "-c", code, str(BINARY)], env=self.env,
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.processes.append(owner)
        # The launcher prints before any potentially blocking discovery/capture work.
        import select
        self.assertTrue(select.select([owner.stdout], [], [], 2)[0], "owner did not publish helper PID")
        helper = int(owner.stdout.readline())
        self.orphan_roots.append(helper)
        wait_for(lambda: any(c["kind"] == "parec" for c in self.children()), "owner's capture not started")
        owner.kill()
        owner.wait(timeout=2)
        wait_for(lambda: not alive(helper), "helper survived owner SIGKILL")
        self.children_gone()


if __name__ == "__main__":
    unittest.main()
