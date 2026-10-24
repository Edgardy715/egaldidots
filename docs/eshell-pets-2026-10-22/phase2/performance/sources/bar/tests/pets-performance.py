#!/usr/bin/env python3
"""Bounded Wayland PetHost benchmark; driver cadence is not physical display FPS."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import queue
import statistics
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("process_sample", ROOT / "bar/tests/sample-process.py")
proc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proc)
SCENARIOS = ["disabled", "idle", "reacting", "hidden", "sleeping"]


def tree(pid):
    result, pending = {}, [pid]
    while pending:
        current = pending.pop()
        path = Path("/proc") / str(current)
        try:
            counts = proc.counters((path / "stat").read_text())
            result[current] = {**counts, **proc.memory(path)}
            pending.extend(int(value) for value in (path / "task" / str(current) / "children").read_text().split())
        except (FileNotFoundError, ProcessLookupError):
            continue
    return result


def parse_marker(line):
    for marker in ("PET_READY", "PET_RESULT", "PET_ERROR", "PET_QUIET"):
        if marker + " " in line:
            return marker, json.loads(line.split(marker + " ", 1)[1])
    return None


def percentile(values, fraction):
    return sorted(values)[min(len(values) - 1, int((len(values) - 1) * fraction))] if values else None


def measure(scenario, seconds, config, log_path):
    env = {**os.environ, "ISLA_CONFIG": str(config), "QT_QPA_PLATFORM": "wayland",
           "ISLA_PET_SCENARIO": scenario, "ISLA_PET_SECONDS": str(round(seconds * 1000)), "NO_COLOR": "1"}
    process = subprocess.Popen(["qs", "-p", str(ROOT / "bar/pets-performance.qml")], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    events, lines = queue.Queue(), []

    def read():
        for line in process.stdout:
            lines.append(line)
            value = parse_marker(line)
            if value:
                events.put(value)
        events.put(("EXIT", process.wait()))

    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    try:
        marker, ready = events.get(timeout=15)
        assert marker == "PET_READY", (marker, ready, "".join(lines))
        first, started = tree(process.pid), time.monotonic()
        assert process.pid in first
        samples = []
        while time.monotonic() - started < seconds:
            time.sleep(min(.25, max(0, seconds - (time.monotonic() - started))))
            current = tree(process.pid)
            assert process.pid in current and current[process.pid]["start_ticks"] == first[process.pid]["start_ticks"]
            samples.append({"at_s": time.monotonic() - started,
                            "pss_kib": sum(row["Pss_kib"] for row in current.values()),
                            "processes": len(current)})
        ended = time.monotonic()
        marker, result = events.get(timeout=3)
        assert marker == "PET_RESULT", (marker, result)
        intervals = result.pop("driverIntervalsMs")
        assert result["unloaded"] == (scenario in ("disabled", "hidden")), result
        if scenario == "sleeping":
            assert result["sleeping"] and result["breathing"], result
            marker, quiet = events.get(timeout=9)
            assert marker == "PET_QUIET" and quiet["sleeping"] and not quiet["breathing"] and quiet["breath"] == 0, (marker, quiet)
            result["quiet_after_8_2s"] = quiet
        if scenario in ("idle", "disabled", "hidden"):
            assert not result["frames"], result
        return {**result, "ready": ready, "seconds": ended - started,
                "tree_cpu_percent": 100 * (sum(row["cpu_ticks"] for row in current.values()) -
                    sum(row["cpu_ticks"] for row in first.values())) / os.sysconf("SC_CLK_TCK") / (ended - started),
                "tree_pss_kib_median": statistics.median(row["pss_kib"] for row in samples),
                "max_processes": max(row["processes"] for row in samples),
                "driver_interval_ms_p50": percentile(intervals, .5),
                "driver_interval_ms_p95": percentile(intervals, .95),
                "driver_interval_ms_max": max(intervals) if intervals else None,
                "driver_intervals_ms": intervals, "samples": samples}
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
        reader.join(timeout=2)
        process.stdout.close()
        log_path.write_text("".join(lines))


def summarize(runs):
    return {name: {key: statistics.median(row[key] for row in runs if row["scenario"] == name)
                   for key in ("tree_cpu_percent", "tree_pss_kib_median", "max_processes")}
            for name in SCENARIOS}


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=8)
    return {"exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/eshell-pets-2026-10-22/phase2/performance")
    parser.add_argument("--seconds", type=float, default=3.5)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert parse_marker('INFO qml: PET_READY {"scenario":"idle"}\n') == ("PET_READY", {"scenario": "idle"})
        assert parse_marker("noise") is None
        assert percentile([9, 1, 4], .5) == 4 and percentile([], .95) is None
        rows = [{"scenario": name, "tree_cpu_percent": value, "tree_pss_kib_median": value + 1,
                 "max_processes": 1} for name in SCENARIOS for value in (2, 4)]
        assert summarize(rows)["idle"]["tree_cpu_percent"] == 3
        assert os.getpid() in tree(os.getpid())
        print("PASS: log parsing, percentiles, paired aggregation and live process tree")
        return
    assert 1 <= args.seconds <= 5, "use a bounded 1..5 second window"
    args.output.mkdir(parents=True, exist_ok=True)
    sources = [*sorted((ROOT / "bar/pets").glob("*.qml")), ROOT / "bar/components/IslandCompanion.qml",
               ROOT / "bar/pets-performance.qml", Path(__file__).resolve(), ROOT / "bar/tests/sample-process.py"]
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    environment = {"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "platform": platform.platform(),
                   "quickshell": command("qs", "--version"), "hyprland": command("hyprctl", "version"),
                   "monitors": command("hyprctl", "monitors", "-j"), "source_sha256": hashes,
                   "seconds_per_scenario": args.seconds, "rounds": 2,
                   "method": "same 160x100 Wayland surface, production PetHost 36x36, 1s warmup excluded; sleeping begins at measurement start; CPU one core; driver FrameAnimation only while animating; no physical FPS"}
    runs = []
    with tempfile.TemporaryDirectory(prefix="isla-pet-performance-") as temporary:
        config = Path(temporary) / "config.json"
        config.write_text("{}\n")
        for round_index in range(2):
            for scenario in SCENARIOS if round_index == 0 else reversed(SCENARIOS):
                result = measure(scenario, args.seconds, config, args.output / f"round{round_index + 1}-{scenario}.log")
                runs.append({"round": round_index + 1, **result})
                print(json.dumps({key: result[key] for key in ("scenario", "tree_cpu_percent", "tree_pss_kib_median", "driver_interval_ms_p95")}), flush=True)
    assert hashes == {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}, "sources changed during benchmark"
    result = {"environment": environment, "runs": runs, "summary": summarize(runs)}
    (args.output / "results.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
