#!/usr/bin/env python3
"""Alternate baseline/native peak reduction, then private two-meter bridge runs."""
import argparse
from array import array
import importlib.util
import json
import math
import os
from pathlib import Path
import runpy
import selectors
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import timeit

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "docs/rust-audio-peak-2026-10-21/baseline/bar/services"
helpers = runpy.run_path(str(ROOT / "bar/tests/cava-hybrid-performance.py"))
pactl, tree, stop = (helpers[key] for key in ("pactl", "tree", "stop"))
TICKS = os.sysconf("SC_CLK_TCK")


def micro(paths, data_home):
    modules = {}
    for name, path in paths.items():
        spec = importlib.util.spec_from_file_location(name, path / "audio_meter.py")
        module = importlib.util.module_from_spec(spec)
        previous = os.environ.get("XDG_DATA_HOME")
        os.environ["XDG_DATA_HOME"] = str(data_home)
        try:
            spec.loader.exec_module(module)
        finally:
            if previous is None:
                os.environ.pop("XDG_DATA_HOME")
            else:
                os.environ["XDG_DATA_HOME"] = previous
        assert (getattr(module, "_native_peak", None) is not None) == (name == "native")
        modules[name] = module
    results = []
    for count in (0, 16, 960, 1920, 8192):
        data = array("f", (.2 * math.sin(i) for i in range(count))).tobytes()
        for round_index in range(4):
            for name in (list(modules) if round_index % 2 == 0 else list(reversed(modules))):
                meter = modules[name].PeakMeter(0)
                meter.feed(data)
                loops = 2000
                elapsed = timeit.timeit(lambda: meter.feed(data), number=loops)
                results.append(dict(backend=name, samples=count, round=round_index,
                                    calls=loops, feed_us=elapsed * 1e6 / loops))
    return results


def measure(path, data_home, backend, sink, mode, seconds, active, shutdown):
    process = subprocess.Popen([sys.executable, str(path / "audio_bridge.py")], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env={**os.environ, "XDG_DATA_HOME": str(data_home)}, bufsize=0)
    observed = set()
    buffer = b""
    selected = selectors.DefaultSelector()
    selected.register(process.stdout, selectors.EVENT_READ)
    os.set_blocking(process.stdout.fileno(), False)

    def message(predicate, timeout=8):
        nonlocal buffer
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                value = json.loads(line)
                assert value.get("type") != "error", value
                if predicate(value):
                    return time.monotonic(), value
            assert selected.select(max(0, deadline - time.monotonic())), "bridge timed out"
            chunk = os.read(process.stdout.fileno(), 65536)
            assert chunk, "bridge exited: " + process.stderr.read().decode()
            buffer += chunk
        raise AssertionError("bridge timed out")

    try:
        _, state = message(lambda m: m.get("type") == "snapshot" and
                           any(row["name"] == sink for row in m["outputs"]) and
                           any(row["appName"].lower() == sink for row in m["playback"]))
        output = next(row for row in state["outputs"] if row["name"] == sink)
        stream = next(row for row in state["playback"] if row["appName"].lower() == sink)
        sources = [stream["meterSource"], output["monitorSource"]] if active else []
        process.stdin.write((json.dumps({"action": "meters", "args": {"sources": sources}}) + "\n").encode())
        process.stdin.flush()
        maps = Path(f"/proc/{process.pid}/maps").read_text()
        assert ("libisla_audio_peak.so" in maps) == (backend == "native"), "wrong backend loaded"
        attack_ms = release_ms = None
        if active:
            deadline = time.monotonic() + .5
            while time.monotonic() < deadline:
                _, value = message(lambda m: m.get("type") == "levels")
                assert all(value["levels"].get(s) == 0 for s in sources), value
            # Timestamp the first submitted tone, not merely the request to the writer.
            mode["written"].clear()
            mode["tone"].set()
            assert mode["written"].wait(2)
            attack_at = mode["at"]
            timestamp, _ = message(lambda m: m.get("type") == "levels" and
                                   all(m["levels"].get(s, 0) > .15 for s in sources))
            attack_ms = (timestamp - attack_at) * 1000
            assert 0 <= attack_ms < 200, attack_ms
            warm_end = time.monotonic() + 1
            while time.monotonic() < warm_end:
                message(lambda m: m.get("type") == "levels")
        else:
            time.sleep(1)
        memories, intervals, rates = [], [], []
        started = time.monotonic()
        before = sum(row["ticks"] for row in tree(process.pid).values())
        sample_at, last_level = started, None
        while time.monotonic() - started < seconds:
            if active:
                timestamp, value = message(lambda m: m.get("type") == "levels")
                assert all(value["levels"].get(s, 0) > .15 for s in sources), "false zero"
                if last_level is not None:
                    intervals.append((timestamp - last_level) * 1000)
                last_level = timestamp
                rates.append(timestamp)
            else:
                selected.select(.05)
                if selected.select(0):
                    buffer += os.read(process.stdout.fileno(), 65536)
            if time.monotonic() >= sample_at:
                current = tree(process.pid)
                observed.update(set(current) - {process.pid})
                memories.append(sum(row["memory"]["Pss"] for row in current.values()))
                sample_at = time.monotonic() + .25
        ended = time.monotonic()
        current = tree(process.pid)
        cpu = 100 * (sum(row["ticks"] for row in current.values()) - before) / TICKS / (ended - started)
        if active:
            mode["written"].clear()
            mode["tone"].clear()
            assert mode["written"].wait(2)
            release_at = mode["at"]
            timestamp, _ = message(lambda m: m.get("type") == "levels" and
                                   all(m["levels"].get(s, 1) == 0 for s in sources))
            release_ms = (timestamp - release_at) * 1000
            assert 0 <= release_ms < 900, release_ms
        result = dict(backend=backend, active=active, duration_s=ended - started,
                      cpu_percent=cpu, pss_kib_median=statistics.median(memories), pss_kib_samples=memories,
                      processes=len(current), attack_ms=attack_ms, release_ms=release_ms,
                      updates_per_second=len(rates) / (ended - started),
                      interval_p95_ms=helpers["percentile"](intervals, .95), shutdown=shutdown,
                      backend_verified=True)
    finally:
        observed.update(set(tree(process.pid)) - {process.pid})
        if shutdown == "EOF":
            process.stdin.close()
            try:
                process.wait(timeout=3)
            finally:
                stop(process)
        else:
            stop(process)
            process.stdin.close()
        selected.close()
        process.stdout.close()
        error = process.stderr.read().decode()
        process.stderr.close()
        assert process.returncode == 0, (process.returncode, error)
        assert not [pid for pid in observed if tree(pid)], "leaked capture/subscription"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--seconds", type=float, default=12)
    parser.add_argument("--rounds", type=int, default=4)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert 2 <= args.rounds <= 8 and math.isfinite(args.seconds) and args.seconds >= 3
    args.output.parent.mkdir(parents=True, exist_ok=True)
    defaults = pactl("get-default-sink"), pactl("get-default-source")
    sink = "isla_peak_bench_" + str(os.getpid())
    module = playback = None
    finished = threading.Event()
    mode = {"tone": threading.Event(), "written": threading.Event(), "at": 0}
    result = {"live": [], "complete": False, "seconds": args.seconds, "rounds": args.rounds}
    with tempfile.TemporaryDirectory(prefix="isla-peak-") as tmp:
        paths = {}
        data_home = Path(tmp) / "data"
        target = data_home / "isla/lib/libisla_audio_peak.so"
        target.parent.mkdir(parents=True)
        shutil.copy2(args.library, target)
        for name in ("baseline", "native"):
            paths[name] = Path(tmp) / name
            shutil.copytree(ROOT / "bar/services", paths[name], ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(BASE / "audio_meter.py", paths["baseline"])
        result["micro"] = micro(paths, data_home)
        try:
            module = pactl("load-module", "module-null-sink", "sink_name=" + sink, "channels=2")
            assert defaults == (pactl("get-default-sink"), pactl("get-default-source"))
            playback = subprocess.Popen(["pacat", "--playback", "--raw", "--format=float32le",
                                         "--rate=48000", "--channels=2", "--device=" + sink,
                                         "--latency-msec=20", "--process-time-msec=10",
                                         "--property=application.name=" + sink], stdin=subprocess.PIPE,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, bufsize=0)
            tone = array("f", (.2 * math.sin(2 * math.pi * 1000 * i / 48000) * sign
                               for i in range(480) for sign in (1, -1))).tobytes()
            if sys.byteorder != "little":
                samples = array("f"); samples.frombytes(tone); samples.byteswap(); tone = samples.tobytes()

            def feed():
                deadline, previous = time.monotonic(), False
                try:
                    while not finished.is_set():
                        on = mode["tone"].is_set()
                        playback.stdin.write(tone if on else bytes(len(tone)))
                        if on != previous:
                            mode["at"] = time.monotonic()
                            mode["written"].set()
                            previous = on
                        deadline += .01
                        finished.wait(max(0, deadline - time.monotonic()))
                except (OSError, ValueError):
                    pass
            writer = threading.Thread(target=feed, daemon=True)
            writer.start()
            for active in (False, True):
                for round_index in range(args.rounds if active else 2):
                    for backend in (list(paths) if round_index % 2 == 0 else list(reversed(paths))):
                        row = measure(paths[backend], data_home, backend, sink, mode,
                                      args.seconds if active else 3, active,
                                      "EOF" if round_index % 2 else "TERM")
                        row["round"] = round_index
                        result["live"].append(row)
                        args.output.write_text(json.dumps(result, indent=2) + "\n")
                        print(backend, "active" if active else "idle", "CPU%", round(row["cpu_percent"], 3),
                              "PSS KiB", row["pss_kib_median"], "attack ms", row["attack_ms"], flush=True)
        finally:
            finished.set()
            stop(playback)
            if playback:
                writer.join(timeout=3)
                playback.stdin.close()
            if module is not None:
                pactl("unload-module", module)
            assert defaults == (pactl("get-default-sink"), pactl("get-default-source")), "defaults changed"
        result.update(complete=True, defaults_preserved=True,
                      scope="bridge + all descendants; shared audio server and producer excluded")
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        print("PASS: native maps, private meters, attack/release, EOF/TERM cleanup and defaults preserved")


if __name__ == "__main__":
    main()
