#!/usr/bin/env python3
"""Sample an existing Linux process without changing its state (CPU = one core)."""
import argparse
import json
import os
from pathlib import Path
import time


def counters(stat):
    fields = stat[stat.rindex(")") + 2:].split()
    return {"cpu_ticks": int(fields[11]) + int(fields[12]),
            "child_cpu_ticks": int(fields[13]) + int(fields[14]),
            "start_ticks": int(fields[19]), "threads": int(fields[17]),
            "rss_kib": int(fields[21]) * os.sysconf("SC_PAGE_SIZE") // 1024}


def memory(process):
    values = {}
    for line in (process / "smaps_rollup").read_text().splitlines():
        if line.startswith(("Rss:", "Pss:", "Private_Dirty:")):
            name, value, _ = line.split()
            values[name[:-1] + "_kib"] = int(value)
    return values


def sample(pid, duration, interval):
    process = Path("/proc") / str(pid)
    first = counters((process / "stat").read_text())
    result = {"pid": pid, "clock_ticks": os.sysconf("SC_CLK_TCK"),
              "memory_before": memory(process), "samples": []}
    started = time.monotonic()
    previous_time, previous = started, first
    while previous_time - started < duration:
        time.sleep(min(interval, duration - (previous_time - started)))
        current = counters((process / "stat").read_text())
        now = time.monotonic()
        if current["start_ticks"] != first["start_ticks"]:
            raise RuntimeError("PID was reused")
        elapsed = now - previous_time
        result["samples"].append({
            "elapsed_s": now - started,
            "cpu_percent": 100 * (current["cpu_ticks"] - previous["cpu_ticks"]) / result["clock_ticks"] / elapsed,
            "child_cpu_percent": 100 * (current["child_cpu_ticks"] - previous["child_cpu_ticks"]) / result["clock_ticks"] / elapsed,
            "rss_kib": current["rss_kib"], "threads": current["threads"]})
        previous_time, previous = now, current
    result["duration_s"] = previous_time - started
    result["cpu_percent"] = 100 * (previous["cpu_ticks"] - first["cpu_ticks"]) / result["clock_ticks"] / result["duration_s"]
    result["child_cpu_percent"] = 100 * (previous["child_cpu_ticks"] - first["child_cpu_ticks"]) / result["clock_ticks"] / result["duration_s"]
    result["memory_after"] = memory(process)
    return result


def positive(value):
    parsed = float(value)
    if not 0 < parsed < float("inf"):
        raise argparse.ArgumentTypeError("must be a finite positive number")
    return parsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int)
    parser.add_argument("--seconds", type=positive, default=30)
    parser.add_argument("--interval", type=positive, default=1)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        fields = ["0"] * 22
        for index, value in {11: 3, 12: 4, 13: 5, 14: 6, 17: 2, 19: 42, 21: 10}.items():
            fields[index] = str(value)
        parsed = counters("123 (name with ) spaces) " + " ".join(fields))
        assert parsed["cpu_ticks"] == 7 and parsed["child_cpu_ticks"] == 11
        assert parsed["start_ticks"] == 42 and parsed["threads"] == 2
        live = sample(os.getpid(), 0.02, 0.01)
        assert live["duration_s"] >= 0.02 and len(live["samples"]) >= 2
        assert live["memory_after"]["Pss_kib"] > 0
        print("PASS: proc parsing, PID identity, bounded sampling and PSS")
        return
    if args.pid is None or args.pid <= 0:
        parser.error("--pid must identify a running process")
    result = sample(args.pid, args.seconds, args.interval)
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "samples"}, indent=2))


if __name__ == "__main__":
    main()
