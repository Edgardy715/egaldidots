"""Compare read-only Cava discovery on a real audio server, without capturing audio."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("process_sample", HERE / "sample-process.py")
sampler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sampler)


def measure(script, seconds):
    # No real MPRIS player uses this test identity; unresolved discovery stays silent.
    identity = "isla-performance-unresolved-" + __import__("uuid").uuid4().hex
    proc = subprocess.Popen([sys.executable, str(script), "--identity", identity],
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        time.sleep(0.5)
        child_ids = (Path(f"/proc/{proc.pid}/task/{proc.pid}/children").read_text().split())
        children = {}
        for pid in child_ids:
            path = Path("/proc") / pid
            try:
                assert (path / "comm").read_text().strip() == "pactl", "unexpected audio capture child"
                children[pid] = sampler.counters((path / "stat").read_text())
            except FileNotFoundError:
                pass
        result = sampler.sample(proc.pid, seconds, 1)
        result["persistent_children"] = []
        for pid, first in children.items():
            path = Path("/proc") / pid
            try:
                final = sampler.counters((path / "stat").read_text())
                if final["start_ticks"] == first["start_ticks"]:
                    result["persistent_children"].append({
                        "cpu_percent": 100 * (final["cpu_ticks"] - first["cpu_ticks"]) / result["clock_ticks"] / result["duration_s"],
                        "memory": sampler.memory(path)})
            except FileNotFoundError:
                pass
    finally:
        proc.terminate()
        _, errors = proc.communicate(timeout=5)
    assert proc.returncode == 0, errors.decode()
    result["stderr"] = errors.decode()
    return result


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--before", type=Path, required=True)
parser.add_argument("--after", type=Path, default=HERE.parent / "services/cava_stream.py")
parser.add_argument("--seconds", type=sampler.positive, default=15)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
results = {"before": measure(args.before, args.seconds), "after": measure(args.after, args.seconds)}
args.output.write_text(json.dumps(results, indent=2) + "\n")
for label, result in results.items():
    total = result["cpu_percent"] + result["child_cpu_percent"] + sum(c["cpu_percent"] for c in result["persistent_children"])
    print(label, "total discovery CPU %", round(total, 3), "parent memory", result["memory_after"],
          "persistent children", result["persistent_children"])
