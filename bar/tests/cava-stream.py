#!/usr/bin/env python3
"""Exact stream selection and bounded capture lifecycle."""

import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
import time
from unittest.mock import Mock, patch


PATH = Path(__file__).resolve().parents[1] / "services" / "cava_stream.py"
sys.path.insert(0, str(PATH.parent))
spec = importlib.util.spec_from_file_location("cava_stream", PATH)
stream = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stream)


def fixture():
    return {
        "clients": [
            {"index": 116, "properties": {"object.id": "108", "application.name": "spotify",
                                           "application.process.binary": "spotify"}},
            {"index": 88, "properties": {"application.name": "Discord",
                                          "application.process.binary": "Discord"}},
        ],
        "sinks": [{"index": 58, "name": "actual", "monitor_source": "actual.monitor"},
                  {"index": 57, "name": "default", "monitor_source": "default.monitor"}],
        "sink-inputs": [
            {"index": 117, "client": "116", "sink": 58, "corked": False,
             "properties": {"client.id": "108", "media.name": "audio-src"}},
            {"index": 118, "client": "88", "sink": 58, "corked": False,
             "properties": {"application.name": "WEBRTC VoiceEngine", "media.name": "playStream"}},
        ],
    }


class CaptureTest(unittest.TestCase):
    def test_spotify_client_identity_and_actual_sink(self):
        self.assertEqual(stream.select_stream(fixture(), "Spotify", "spotify.desktop",
                                              "org.mpris.MediaPlayer2.spotify"),
                         (117, "actual.monitor"))
        self.assertEqual(stream.select_stream(fixture(), "Discord", "discord.desktop", ""),
                         (118, "actual.monitor"))

    def test_missing_corked_ambiguous_and_mismatched_are_silent(self):
        self.assertIsNone(stream.select_stream(fixture(), "Tidal", "tidal.desktop", ""))
        self.assertIsNone(stream.select_stream(fixture(), "", "", ""))
        data = fixture()
        data["sink-inputs"][0]["corked"] = True
        self.assertIsNone(stream.select_stream(data, "Spotify", "spotify", ""))
        data = fixture()
        data["sink-inputs"].append({**data["sink-inputs"][0], "index": 119})
        self.assertIsNone(stream.select_stream(data, "Spotify", "spotify", ""))
        data = fixture()
        data["sink-inputs"][0]["sink"] = 999
        self.assertIsNone(stream.select_stream(data, "Spotify", "spotify", ""))

    def test_config_and_bounded_cleanup(self):
        with tempfile.TemporaryDirectory() as temp:
            capture = stream.Capture(temp)
            content = capture.cfg.read_text()
            for field in ("method = fifo", "sample_bits = 16", "sample_rate = 44100",
                          "channels = 2", "autosens = 0", "sensitivity = 100",
                          "noise_reduction = 0", "lower_cutoff_freq = 60",
                          "ascii_max_range = 65535"):
                self.assertIn(field, content)
            self.assertTrue(capture.fifo.is_fifo())
            capture.stop()
        proc = Mock()
        proc.poll.return_value = None
        proc.wait.side_effect = [subprocess.TimeoutExpired("fake", 0.5), 0]
        proc.stdout = None
        proc.stdin = None
        stream.stop_process(proc)
        proc.terminate.assert_called_once()
        proc.kill.assert_called_once()

    def test_parec_targets_selected_stream_and_sink(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(stream.subprocess, "Popen") as popen, \
             patch.object(stream.os, "open", return_value=12), \
             patch.object(stream.os, "set_blocking"), patch.object(stream.os, "close"):
            capture = stream.Capture(temp)
            fake = Mock()
            fake.poll.return_value = None
            fake.stdout.fileno.return_value = 9
            popen.return_value = fake
            capture.start(117, "actual.monitor")
            self.assertEqual(popen.call_args_list[1].args[0], [
                "parec", "--monitor-stream", "117", "--device", "actual.monitor",
                "--raw", "--format=s16le", "--rate=44100", "--channels=2",
                "--latency-msec=20"])
            capture.stop()

    def test_sigkill_parent_kills_child(self):
        code = ("import os,signal,subprocess,time,sys; "
                "from cava_stream import die_with_parent; "
                "parent=os.getpid(); "
                "p=subprocess.Popen(['sleep','30'], "
                "preexec_fn=lambda: die_with_parent(parent)); "
                "print(p.pid,flush=True); time.sleep(30)")
        parent = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE,
                                  env={**os.environ, "PYTHONPATH": str(PATH.parent)}, text=True)
        child = None
        try:
            child = int(parent.stdout.readline())
            parent.kill()
            parent.wait(timeout=2)
            for _ in range(50):
                stat = Path(f"/proc/{child}/stat")
                if not stat.exists() or stat.read_text().split()[2] == "Z":
                    break
                time.sleep(0.02)
            else:
                self.fail("child survived parent SIGKILL")
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait(timeout=2)
            parent.stdout.close()
            if child and Path(f"/proc/{child}/stat").exists():
                try:
                    if Path(f"/proc/{child}/stat").read_text().split()[2] != "Z":
                        os.kill(child, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def test_subscription_event_filter(self):
        for line in (b"Event 'new' on sink-input #4", b"Event 'remove' on sink #1",
                     b"Event 'change' on server #0"):
            self.assertIsNotNone(stream.DISCOVERY_EVENT.search(line), line)
        for line in (b"Event 'new' on client #9", b"Event 'remove' on client #9",
                     b"Event 'change' on client #9",
                     b"Event 'new' on source-output #2", b"Event 'change' on source #1"):
            self.assertIsNone(stream.DISCOVERY_EVENT.search(line), line)
        owners = stream.stream_clients(fixture())
        self.assertEqual(owners, {"116", "88"})
        self.assertTrue(stream.discovery_event(b"Event 'change' on client #116", owners))
        self.assertFalse(stream.discovery_event(b"Event 'change' on client #9", owners))
        data = fixture()
        data["sink-inputs"][0]["client"] = None
        self.assertIn("116", stream.stream_clients(data), "PipeWire client object ID resolves to Pulse index")

    def test_discovery_events_reconcile_and_reconnect_without_polling(self):
        with tempfile.TemporaryDirectory(prefix="isla-cava-events-") as directory:
            root = Path(directory)
            log = root / "calls"
            events = root / "events"
            os.mkfifo(events, 0o600)
            # An unresolved player never starts parec or Cava; only read-only discovery runs.
            pactl = root / "pactl"
            pactl.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ["ISLA_CAVA_FIXTURE"])
with (root / "calls").open("a") as log:
    log.write(json.dumps({"pid": os.getpid(), "args": sys.argv[1:]}) + "\\n")
if sys.argv[1:] == ["subscribe"]:
    with (root / "events").open() as events:
        for line in events:
            if line.strip() == "disconnect":
                break
            sys.stdout.write(line)
            sys.stdout.flush()
elif (root / "fail").exists():
    sys.exit(1)
else:
    data = json.loads((root / "state").read_text()) if (root / "state").exists() else {}
    print(json.dumps(data.get(sys.argv[-1], [])))
''')
            pactl.chmod(0o755)
            cava = root / "cava"
            cava.write_text(r'''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
root = Path(os.environ["ISLA_CAVA_FIXTURE"])
with (root / "captures").open("a") as log:
    log.write(json.dumps({"kind": "cava", "pid": os.getpid()}) + "\n")
config = Path(sys.argv[2]).read_text()
fifo = next(line.split(" = ", 1)[1] for line in config.splitlines() if line.startswith("source = "))
reader = os.open(fifo, os.O_RDONLY)
os.set_blocking(reader, False)
while True:
    try:
        os.read(reader, 65536)
    except BlockingIOError:
        pass
    print(" ".join(["32768"] * 24), flush=True)
    time.sleep(0.02)
''')
            cava.chmod(0o755)
            parec = root / "parec"
            parec.write_text(r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ["ISLA_CAVA_FIXTURE"])
with (root / "captures").open("a") as log:
    log.write(json.dumps({"kind": "parec", "pid": os.getpid(), "args": sys.argv[1:]}) + "\n")
while True:
    os.write(1, b"\0" * 4096)
''')
            parec.chmod(0o755)
            env = {**os.environ, "PATH": str(root) + ":" + os.environ["PATH"],
                   "ISLA_CAVA_FIXTURE": str(root)}
            binary = os.environ.get("ISLA_CAVA_TEST_BINARY")
            command = [binary] if binary else [sys.executable, str(PATH)]
            proc = subprocess.Popen([*command, "--identity", "isla-test-unresolved"],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            writer = None

            def calls():
                return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

            def query_count():
                return sum(item["args"] != ["subscribe"] for item in calls())

            def captures():
                path = root / "captures"
                return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

            def capture_gone(pids):
                return all(not Path(f"/proc/{pid}").exists() for pid in pids)

            def wait_for(condition, message):
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if condition():
                        return
                    self.assertIsNone(proc.poll(), "discovery process exited early")
                    time.sleep(0.02)
                self.fail(message)

            def connect():
                nonlocal writer
                if writer is not None:
                    os.close(writer)
                    writer = None
                def opened():
                    nonlocal writer
                    try:
                        writer = os.open(events, os.O_WRONLY | os.O_NONBLOCK)
                        return True
                    except OSError:
                        return False
                wait_for(opened, "subscription failed to open")

            try:
                connect()
                wait_for(lambda: query_count() == 3, "initial snapshot missing")
                time.sleep(1.2)
                self.assertEqual(query_count(), 3, "unchanged streams were polled")
                os.write(writer, b"Event 'new' on client #4\nEvent 'change' on client #4\nEvent 'remove' on client #4\n")
                time.sleep(0.2)
                self.assertEqual(query_count(), 3, "client discovery caused a feedback loop")
                # Partial lines wait for newline; a burst must produce one snapshot.
                os.write(writer, b"Event 'change' on sink-in")
                time.sleep(0.1)
                self.assertEqual(query_count(), 3)
                os.write(writer, b"put #4\n" + b"Event 'change' on sink-input #4\n" * 20)
                wait_for(lambda: query_count() >= 6, "event snapshot missing")
                time.sleep(0.2)
                self.assertEqual(query_count(), 6, "event burst was not coalesced")
                (root / "fail").touch()
                os.write(writer, b"Event 'remove' on sink-input #4\n")
                wait_for(lambda: query_count() > 6, "failed discovery not attempted")
                (root / "fail").unlink()
                before = query_count()
                wait_for(lambda: query_count() >= before + 3, "discovery did not retry after failure")
                os.write(writer, b"disconnect\n")
                os.close(writer)
                writer = None
                wait_for(lambda: sum(c["args"] == ["subscribe"] for c in calls()) >= 2,
                         "subscription did not reconnect")
                connect()
                before = query_count()
                os.write(writer, b"Event 'change' on server #0\n")
                wait_for(lambda: query_count() >= before + 3, "reconnected discovery did not refresh")

                # Real main/Capture/pipe multiplexing, with synthetic producers only.
                data = fixture()
                data["clients"][0]["properties"].update({
                    "application.name": "isla-test-unresolved", "application.process.binary": "isla-test-unresolved"})
                (root / "state").write_text(json.dumps(data))
                os.write(writer, b"Event 'new' on sink-input #117\n")
                wait_for(lambda: len(captures()) >= 2, "selected stream did not start synthetic capture")
                first_pids = [item["pid"] for item in captures()]
                first_parec = next(item for item in captures() if item["kind"] == "parec")
                self.assertEqual(first_parec["args"][:4], ["--monitor-stream", "117", "--device", "actual.monitor"])

                # Metadata of an owning client matters; unrelated pactl clients do not.
                data["clients"][0]["properties"].update({"application.name": "other", "application.process.binary": "other"})
                (root / "state").write_text(json.dumps(data))
                os.write(writer, b"Event 'change' on client #116\n")
                wait_for(lambda: capture_gone(first_pids), "client identity change kept stale capture alive")

                data["clients"][0]["properties"].update({
                    "application.name": "isla-test-unresolved", "application.process.binary": "isla-test-unresolved"})
                data["sink-inputs"][0]["sink"] = 57
                (root / "state").write_text(json.dumps(data))
                os.write(writer, b"Event 'change' on sink-input #117\n")
                wait_for(lambda: len(captures()) >= 4, "rerouted stream did not restart capture")
                self.assertEqual([item for item in captures() if item["kind"] == "parec"][-1]["args"][:4],
                                 ["--monitor-stream", "117", "--device", "default.monitor"])
                active_pids = [item["pid"] for item in captures()][-2:]
                subscriptions = sum(c["args"] == ["subscribe"] for c in calls())
                os.write(writer, b"disconnect\n")
                os.close(writer)
                writer = None
                wait_for(lambda: capture_gone(active_pids), "disconnect leaked active capture")
                wait_for(lambda: sum(c["args"] == ["subscribe"] for c in calls()) > subscriptions,
                         "active capture did not reconnect")
                connect()
                wait_for(lambda: len(captures()) >= 6, "capture did not resume after reconnection")
            finally:
                if writer is not None:
                    os.close(writer)
                proc.terminate()
                proc.wait(timeout=4)
            for call in calls():
                if call["args"] == ["subscribe"]:
                    self.assertFalse(Path(f'/proc/{call["pid"]}').exists(), "subscription leaked")
            self.assertTrue(capture_gone([item["pid"] for item in captures()]), "capture children leaked")


if __name__ == "__main__":
    unittest.main()
