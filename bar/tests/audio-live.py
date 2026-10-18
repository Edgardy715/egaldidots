#!/usr/bin/env python3
"""Opt-in real PipeWire/PulseAudio check using two private, inaudible null sinks."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


def pactl(*args):
    result = subprocess.run(["pactl", *args], check=True, capture_output=True, text=True,
                            env={**os.environ, "LC_ALL": "C.UTF-8"}, timeout=8)
    return result.stdout.strip()


def main():
    prefix = "isla_audio_test_" + str(os.getpid())
    defaults = (pactl("get-default-sink"), pactl("get-default-source"))
    modules, processes = [], []
    helper = None
    try:
        for suffix in ("a", "b"):
            modules.append(pactl("load-module", "module-null-sink", "sink_name=" + prefix + suffix,
                                 "sink_properties=device.description=IslaAudioTest", "channels=2"))
        playback = subprocess.Popen(["pacat", "--playback", "--raw", "--format=float32le", "--rate=8000", "--channels=1",
                                     "--device=" + prefix + "a", "--property=application.name=Isla Audio Test"], stdin=subprocess.PIPE)
        processes.append(playback)
        stop = threading.Event()
        def feed():
            import array
            import math
            chunk = array.array("f", (0.12 * math.sin(i * 2 * math.pi * 440 / 8000) for i in range(800)))
            try:
                while not stop.is_set():
                    playback.stdin.write(chunk.tobytes())
                    playback.stdin.flush()
                    stop.wait(.1)
            except (BrokenPipeError, ValueError):
                pass
        threading.Thread(target=feed, daemon=True).start()
        capture = subprocess.Popen(["parec", "--raw", "--device=" + prefix + "a.monitor",
                                    "--property=application.name=Isla Audio Test Capture"], stdout=subprocess.DEVNULL)
        processes.append(capture)
        helper = subprocess.Popen([sys.executable, str(Path(__file__).resolve().parents[1] / "services/audio_bridge.py")],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        messages = queue.Queue()
        def read():
            for line in helper.stdout:
                messages.put(json.loads(line))
        threading.Thread(target=read, daemon=True).start()
        def send(action, args):
            helper.stdin.write(json.dumps({"action":action,"args":args}) + "\n")
            helper.stdin.flush()
        def await_message(predicate, timeout=8):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                message = messages.get(timeout=max(.01, deadline-time.monotonic()))
                if message.get("type") == "error":
                    raise AssertionError(message)
                if predicate(message):
                    return message
            raise AssertionError("Timed out")
        state = await_message(lambda m: m.get("type") == "snapshot" and any(r["appName"] == "Isla Audio Test" for r in m["playback"]) and any(r["appName"] == "Isla Audio Test Capture" for r in m["recording"]))
        first = next(r for r in state["outputs"] if r["name"] == prefix+"a")
        second = next(r for r in state["outputs"] if r["name"] == prefix+"b")
        stream = next(r for r in state["playback"] if r["appName"] == "Isla Audio Test")
        recording = next(r for r in state["recording"] if r["appName"] == "Isla Audio Test Capture")
        if first.get("canRename"):
            send("renameDevice", {"kind":"output","id":first["id"],"description":"Isla Audio Test Renamed"})
            await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==first["id"] and r["description"]=="Isla Audio Test Renamed" for r in m["outputs"]))
        else:
            print("SKIP: device rename is unsupported by this PipeWire server (confirmed Not supported)")
        send("setVolume", {"kind":"output","id":first["id"],"volume":.4})
        await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==first["id"] and abs(r["volume"]-.4)<.002 for r in m["outputs"]))
        send("setChannelVolumes", {"kind":"output","id":first["id"],"volumes":[.2,.4]})
        await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==first["id"] and abs(r["channels"][0]["volume"]-.2)<.002 for r in m["outputs"]))
        send("setMute", {"kind":"output","id":first["id"],"mute":True})
        await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==first["id"] and r["mute"] for r in m["outputs"]))
        send("setMute", {"kind":"output","id":first["id"],"mute":False})
        send("meters", {"sources":[stream["meterSource"]]})
        await_message(lambda m: m.get("type")=="levels" and m["levels"].get(stream["meterSource"],0)>0, 10)
        send("moveStream", {"kind":"playback","id":stream["id"],"device":second["id"]})
        await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==stream["id"] and r["device"]==second["id"] for r in m["playback"]))
        monitor = next(r for r in state["inputs"] if r["name"]==prefix+"b.monitor")
        send("moveStream", {"kind":"recording","id":recording["id"],"device":monitor["id"]})
        await_message(lambda m: m.get("type")=="snapshot" and any(r["id"]==recording["id"] and r["device"]==monitor["id"] for r in m["recording"]))
        print("PASS: real private audio volume, per-channel levels, mute, playback/capture routing and actual signal peaks")
    finally:
        if helper:
            helper.terminate()
            helper.wait(timeout=5)
        if processes:
            stop.set()
        for process in processes:
            process.terminate()
            process.wait(timeout=3)
        for module in reversed(modules):
            pactl("unload-module", module)
        assert defaults == (pactl("get-default-sink"), pactl("get-default-source")), "Default devices changed"
        print("PASS: private nodes/processes removed and user's defaults preserved")


if __name__ == "__main__":
    main()
