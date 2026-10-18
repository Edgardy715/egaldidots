#!/usr/bin/env python3
"""Live, private null-sink timing check for playback and output peak meters."""

from array import array
import json
import math
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


BRIDGE = Path(__file__).resolve().parents[1] / "services" / "audio_bridge.py"


def pactl(*args):
    return subprocess.run(["pactl", *args], check=True, capture_output=True, text=True,
                          env={**os.environ, "LC_ALL": "C.UTF-8"}, timeout=8).stdout.strip()


def stop_process(process):
    if process is None:
        return
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def main():
    defaults = (pactl("get-default-sink"), pactl("get-default-source"))
    sink_name = "isla_meter_timing_" + str(os.getpid())
    module = None
    playback = helper = None
    stop = threading.Event()
    mode = threading.Event()
    writes = queue.Queue()
    messages = queue.Queue()
    try:
        module = pactl("load-module", "module-null-sink", "sink_name=" + sink_name,
                       "sink_properties=device.description=IslaMeterTiming", "channels=2")
        playback = subprocess.Popen([
            "pacat", "--playback", "--raw", "--format=float32le", "--rate=48000", "--channels=2",
            "--latency-msec=20", "--process-time-msec=10", "--device=" + sink_name,
            "--property=application.name=Isla Meter Timing"], stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, bufsize=0)
        samples = array("f", (0.2 * math.sin(2 * math.pi * 1000 * i / 48000) * sign
                              for i in range(480) for sign in (1, -1)))
        tone, silence = samples.tobytes(), bytes(len(samples) * 4)

        def feed():
            next_write = time.monotonic()
            previous = False
            try:
                while not stop.is_set():
                    on = mode.is_set()
                    playback.stdin.write(tone if on else silence)
                    if on != previous:
                        writes.put((on, time.monotonic()))
                        previous = on
                    next_write += .01
                    stop.wait(max(0, next_write - time.monotonic()))
            except (BrokenPipeError, ValueError, OSError):
                pass

        writer = threading.Thread(target=feed, daemon=True)
        writer.start()
        helper = subprocess.Popen([sys.executable, str(BRIDGE)], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)

        def read():
            for line in helper.stdout:
                messages.put((time.monotonic(), json.loads(line)))

        reader = threading.Thread(target=read, daemon=True)
        reader.start()

        def await_message(predicate, timeout=8):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                try:
                    timestamp, message = messages.get(timeout=max(.01, deadline - time.monotonic()))
                except queue.Empty:
                    break
                if message.get("type") == "error":
                    raise AssertionError(message["message"])
                if predicate(message):
                    return timestamp, message
            raise AssertionError("Timed out waiting for audio bridge")

        _, state = await_message(lambda m: m.get("type") == "snapshot" and
                                  any(row["appName"] == "Isla Meter Timing" for row in m["playback"]))
        output = next(row for row in state["outputs"] if row["name"] == sink_name)
        stream = next(row for row in state["playback"] if row["appName"] == "Isla Meter Timing")
        sources = [stream["meterSource"], output["monitorSource"]]
        helper.stdin.write(json.dumps({"action": "meters", "args": {"sources": sources}}) + "\n")
        helper.stdin.flush()
        await_message(lambda m: m.get("type") == "levels" and all(source in m["levels"] for source in sources))
        # Warm the capture processes while a continuous silent stream is already flowing.
        baseline_end = time.monotonic() + .35
        while time.monotonic() < baseline_end:
            _, message = await_message(lambda m: m.get("type") == "levels")
            assert all(message["levels"][source] == 0 for source in sources), message

        mode.set()
        on, attack_start = writes.get(timeout=1)
        assert on
        attacks = {}
        sustained = []
        tone_end = attack_start + 1.0
        while time.monotonic() < tone_end:
            timestamp, message = await_message(lambda m: m.get("type") == "levels")
            for source in sources:
                level = message["levels"].get(source, 0)
                if source not in attacks and level > .15:
                    attacks[source] = timestamp - attack_start
                if timestamp >= attack_start + .25:
                    sustained.append((source, level))
        assert set(attacks) == set(sources), f"No meter attack: {attacks}"
        assert all(0 <= latency <= .2 for latency in attacks.values()), f"Slow attack: {attacks}"
        assert sustained and all(level > .15 for _, level in sustained), "False zero during sustained tone"

        mode.clear()
        on, release_start = writes.get(timeout=1)
        assert not on
        releases = {}
        deadline = release_start + .9
        while time.monotonic() < deadline and len(releases) < len(sources):
            timestamp, message = await_message(lambda m: m.get("type") == "levels", timeout=1)
            for source in sources:
                if source not in releases and message["levels"].get(source, 1) == 0:
                    releases[source] = timestamp - release_start
        assert set(releases) == set(sources), f"Meter failed to release to zero: {releases}"
        assert all(0 <= latency <= .9 for latency in releases.values()), f"Slow release: {releases}"
        print("PASS: private antiphase stereo tone; attack " +
              ", ".join(f"{source}={attacks[source] * 1000:.0f}ms" for source in sources))
        print("PASS: sustained tone has no false zero; release " +
              ", ".join(f"{source}={releases[source] * 1000:.0f}ms" for source in sources))
    finally:
        stop.set()
        if playback and playback.stdin:
            playback.stdin.close()
        stop_process(helper)
        stop_process(playback)
        if module is not None:
            pactl("unload-module", module)
        assert defaults == (pactl("get-default-sink"), pactl("get-default-source")), "Default devices changed"
        print("PASS: private module removed and default devices preserved")


if __name__ == "__main__":
    main()
