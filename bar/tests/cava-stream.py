#!/usr/bin/env python3
"""Exact stream selection and bounded capture lifecycle."""

import importlib.util
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


if __name__ == "__main__":
    unittest.main()
