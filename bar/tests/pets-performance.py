#!/usr/bin/env python3
"""Bounded Wayland pet benchmark; counts frames the fixture window presents (frameSwapped)."""
import argparse
import hashlib
import importlib.util
import json
import math
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
SCENARIOS = ["disabled", "idle", "walking", "reacting", "dancing", "hidden", "sleeping", "flying", "coding", "rail-idle"]
LEGACY_SCENARIOS = ["disabled", "idle", "reacting", "hidden", "sleeping"]


def tree(pid):
    result, pending = {}, [pid]
    while pending:
        current = pending.pop()
        path = Path("/proc") / str(current)
        try:
            counts = proc.counters((path / "stat").read_text())
            tasks = sorted((path / "task").iterdir())
            result[current] = {**counts, **proc.memory(path),
                               "cpu_ns": sum(int((task / "schedstat").read_text().split()[0]) for task in tasks),
                               "threads": [task.name for task in tasks]}
            pending.extend(int(value) for value in (path / "task" / str(current) / "children").read_text().split())
        except (FileNotFoundError, ProcessLookupError):
            continue
    return result


def parse_marker(line):
    for marker in ("PET_READY", "PET_RESULT", "PET_ERROR"):
        if marker + " " in line:
            return marker, json.loads(line.split(marker + " ", 1)[1])
    return None


def steady_cpu(samples, seconds, counter="cpu_ns", units=1e9):
    # Exclude the ready/result logging and their two window presentations.
    interior = [row for row in samples if row["at_s"] <= seconds - .25]
    first, last = interior[0], interior[-1]
    return 100 * (last[counter] - first[counter]) / units / (last["at_s"] - first["at_s"])


def measure(impl, scenario, seconds, config, log_path):
    env = {**os.environ, "ISLA_CONFIG": str(config), "QT_QPA_PLATFORM": "wayland", "ISLA_PET_IMPL": impl,
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
            assert {pid: row["threads"] for pid, row in current.items()} == {pid: row["threads"] for pid, row in first.items()}, "CPU accounting requires a stable warmed process/thread tree"
            samples.append({"at_s": time.monotonic() - started,
                            "pss_kib": sum(row["Pss_kib"] for row in current.values()),
                            "cpu_ticks": sum(row["cpu_ticks"] for row in current.values()),
                            "cpu_ns": sum(row["cpu_ns"] for row in current.values()),
                            "processes": len(current)})
        ended = time.monotonic()
        marker, result = events.get(timeout=3)
        assert marker == "PET_RESULT", (marker, result)
        state = result["state"]
        if impl == "mimo" and scenario == "sleeping":
            assert state["asleep"] and state["settled"], result
        if impl == "mimo" and scenario == "coding":
            assert state["anim"] == "code" and state["settled"], result
        if impl == "mimo" and scenario in ("idle", "rail-idle"):
            assert ready["state"]["anim"] == state["anim"] == "idle", (ready, result)
        if impl == "mimo" and scenario == "flying":
            assert result["flightStarts"] == math.ceil(seconds), result
        if scenario == "hidden" and impl == "mimo":
            assert not state["shown"], result
        if scenario in ("disabled", "hidden") or (impl == "mimo" and scenario == "sleeping"):
            assert result["framesPerSecond"] <= 1, ("a still scenario must stay near zero frames", result)
        return {**result, "ready": ready, "seconds": ended - started,
                "tree_cpu_percent": steady_cpu(samples, seconds),
                "tree_cpu_percent_ticks": steady_cpu(samples, seconds, "cpu_ticks", os.sysconf("SC_CLK_TCK")),
                "tree_cpu_percent_including_markers": 100 * (sum(row["cpu_ns"] for row in current.values()) -
                    sum(row["cpu_ns"] for row in first.values())) / 1e9 / (ended - started),
                "tree_pss_kib_median": statistics.median(row["pss_kib"] for row in samples),
                "max_processes": max(row["processes"] for row in samples), "samples": samples}
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
    names = list(dict.fromkeys(row["scenario"] for row in runs))
    return {name: {key: statistics.median(row[key] for row in runs if row["scenario"] == name)
                   for key in ("tree_cpu_percent", "tree_pss_kib_median", "max_processes", "framesPerSecond")}
            for name in names}


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=8)
    return {"exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}


def offscreen_processes():
    found = []
    for path in Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            if (path / "comm").read_text().strip() in ("qs", "quickshell") and b"QT_QPA_PLATFORM=offscreen" in (path / "environ").read_bytes().split(b"\0"):
                found.append(int(path.name))
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/eshell-pets-redesign-2026-10-23/perf/after-isolated")
    parser.add_argument("--impl", choices=("mimo", "legacy"), default="mimo")
    parser.add_argument("--seconds", type=float, default=3.5)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--baseline", type=Path, default=ROOT / "docs/eshell-pets-redesign-2026-10-23/perf/after-isolated/results.json",
                        help="phase-1 PSS reference; use a matched rerun when the historical environment drifted")
    args = parser.parse_args()
    if args.self_test:
        assert parse_marker('INFO qml: PET_READY {"scenario":"idle"}\n') == ("PET_READY", {"scenario": "idle"})
        assert parse_marker("noise") is None
        rows = [{"scenario": name, "tree_cpu_percent": value, "tree_pss_kib_median": value + 1,
                 "max_processes": 1, "framesPerSecond": value} for name in SCENARIOS for value in (2, 4)]
        assert summarize(rows)["idle"]["tree_cpu_percent"] == 3
        assert os.getpid() in tree(os.getpid())
        assert steady_cpu([{"at_s": at, "cpu_ns": ns} for at, ns in ((.25, 5), (.5, 5), (.75, 5), (1, 10))], 1) == 0
        assert steady_cpu([{"at_s": .25, "cpu_ns": 1000000}, {"at_s": .75, "cpu_ns": 6000000}], 1) == 1
        assert round(.049, 1) == 0 and round(.051, 1) != 0
        print("PASS: log parsing, paired aggregation and live process tree")
        return
    assert 1 <= args.seconds <= 5, "use a bounded 1..5 second window"
    assert not offscreen_processes(), f"stop abandoned offscreen fixtures before measuring: {offscreen_processes()}"
    args.output.mkdir(parents=True, exist_ok=True)
    sources = [*sorted((ROOT / "bar/pets").glob("*.qml")), *sorted((ROOT / "bar/pets").glob("*.js")),
               *sorted((ROOT / "bar/pets/packs").glob("*/atlas.*")), ROOT / "bar/components/TopWorkspaceRail.qml",
               ROOT / "bar/pets-performance.qml", Path(__file__).resolve(), ROOT / "bar/tests/sample-process.py"]
    scenarios = SCENARIOS if args.impl == "mimo" else LEGACY_SCENARIOS
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    environment = {"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "platform": platform.platform(),
                   "quickshell": command("qs", "--version"), "hyprland": command("hyprctl", "version"),
                   "monitors": command("hyprctl", "monitors", "-j"), "source_sha256": hashes,
                   "seconds_per_scenario": args.seconds, "rounds": 2,
                   "impl": args.impl,
                   "method": "same 200x100 Wayland surface; Mimo line perch x2, rail-idle real compact rail; idle/rail-idle fixed RNG0.99 exclude spontaneous reactions/walking; flying changes perch once/second; coding/sleeping settle before measuring; Window.frameSwapped (no render driver); CPU one core via per-thread schedstat nanoseconds, stable thread tree, excludes first/last250ms probe markers (full-window and quantized tick CPU retained); zero CPU reported to one decimal; no offscreen processes"}
    runs = []
    with tempfile.TemporaryDirectory(prefix="isla-pet-performance-") as temporary:
        config = Path(temporary) / "config.json"
        config.write_text("{}\n")
        for round_index in range(2):
            for scenario in scenarios if round_index == 0 else reversed(scenarios):
                result = measure(args.impl, scenario, args.seconds, config, args.output / f"round{round_index + 1}-{scenario}.log")
                runs.append({"round": round_index + 1, **result})
                print(json.dumps({key: result[key] for key in ("scenario", "tree_cpu_percent", "tree_pss_kib_median", "framesPerSecond")}), flush=True)
    assert hashes == {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}, "sources changed during benchmark"
    summary = summarize(runs)
    checks = {}
    if args.impl == "mimo":
        for scenario in ("disabled", "hidden", "sleeping"):
            checks[scenario] = summary[scenario]["framesPerSecond"] <= 1 and round(summary[scenario]["tree_cpu_percent"], 1) == 0
        for scenario in ("idle", "rail-idle", "coding"):
            checks[scenario] = summary[scenario]["framesPerSecond"] <= 1.5
        checks["flying-cpu"] = summary["flying"]["tree_cpu_percent"] < 2
        baseline = json.loads(args.baseline.read_text())
        checks["idle-pss"] = summary["idle"]["tree_pss_kib_median"] <= baseline["summary"]["idle"]["tree_pss_kib_median"] + 2048
    result = {"environment": environment, "runs": runs, "summary": summary, "checks": checks,
              "baseline": str(args.baseline), "historical_summary": json.loads((ROOT / "docs/eshell-pets-redesign-2026-10-23/perf/after-isolated/results.json").read_text())["summary"]}
    (args.output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    assert all(checks.values()), checks


if __name__ == "__main__":
    main()
