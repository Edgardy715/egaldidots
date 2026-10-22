"""Compare helper process trees using real Cava and a private, inaudible Pulse sink."""
import argparse
from array import array
import json
import math
import os
from pathlib import Path
import selectors
import statistics
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
TICKS = os.sysconf("SC_CLK_TCK")


def pactl(*args):
    return subprocess.run(["pactl", *args], check=True, capture_output=True, text=True,
                          env={**os.environ, "LC_ALL": "C.UTF-8"}, timeout=8).stdout.strip()


def stop(process):
    if process is None:
        return
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def tree(pid):
    result, pending = {}, [pid]
    while pending:
        current = pending.pop()
        path = Path("/proc") / str(current)
        try:
            text = (path / "stat").read_text()
            fields = text[text.rindex(")") + 2:].split()
            if fields[0] == "Z":
                continue
            memory = {}
            for line in (path / "smaps_rollup").read_text().splitlines():
                if line.startswith(("Rss:", "Pss:")):
                    key, value, _ = line.split()
                    memory[key.rstrip(":")] = int(value)
            result[current] = {
                "ticks": sum(int(fields[i]) for i in (11, 12, 13, 14)),
                "memory": memory,
                "argv": [x.decode(errors="replace") for x in (path / "cmdline").read_bytes().split(b"\0") if x]}
            pending.extend(int(child) for child in (path / "task" / str(current) / "children").read_text().split())
        except (FileNotFoundError, ProcessLookupError):
            continue
    return result


def percentile(values, fraction):
    return sorted(values)[min(len(values) - 1, int(len(values) * fraction))] if values else None


def measure(command, identity, seconds, active, stream_id, sink):
    started = time.monotonic()
    process = subprocess.Popen([*command, "--identity", identity], stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, bufsize=0)
    before_ticks = None
    before_at = 0
    frame_count = 0
    first_frame = first_signal = None
    intervals, memories, frames = [], [], []
    last_frame = None
    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    next_sample = started + 1
    observed_children = set()
    final_tree = {}
    with selectors.DefaultSelector() as selected:
        for name in buffers:
            pipe = getattr(process, name)
            os.set_blocking(pipe.fileno(), False)
            selected.register(pipe, selectors.EVENT_READ, name)
        try:
            while True:
                now = time.monotonic()
                assert process.poll() is None, "helper exited early: " + buffers["stderr"].decode(errors="replace")
                if now >= next_sample:
                    current = tree(process.pid)
                    assert process.pid in current, "missing helper"
                    observed_children.update(set(current) - {process.pid})
                    total_ticks = sum(item["ticks"] for item in current.values())
                    if before_ticks is None:
                        before_ticks, before_at = total_ticks, now
                        frame_count = 0
                        frames.clear()
                        intervals.clear()
                        last_frame = None
                    memories.append({key: sum(item["memory"][key] for item in current.values()) for key in ("Rss", "Pss")})
                    next_sample = now + .25
                    if now - before_at >= seconds:
                        final_tree, final_ticks, ended = current, total_ticks, now
                        break
                for key, _ in selected.select(.03):
                    data = os.read(key.fileobj.fileno(), 65536)
                    assert data, "helper pipe closed before measurement finished"
                    name = key.data
                    buffers[name].extend(data)
                    assert len(buffers[name]) < 1024 * 1024, "unbounded helper output"
                    if name == "stderr":
                        continue
                    while b"\n" in buffers[name]:
                        line, _, remainder = buffers[name].partition(b"\n")
                        buffers[name] = bytearray(remainder)
                        values = [int(value) for value in line.split()]
                        assert len(values) == 24 and all(0 <= value <= 65535 for value in values), "invalid spectrum frame"
                        at = time.monotonic()
                        if first_frame is None:
                            first_frame = at - started
                        if any(values) and first_signal is None:
                            first_signal = at - started
                        if before_ticks is not None:
                            frame_count += 1
                            frames.append(values)
                            if last_frame is not None:
                                intervals.append((at - last_frame) * 1000)
                            last_frame = at
            duration = ended - before_at
            argv = [item["argv"] for item in final_tree.values()]
            if active:
                captures = [args for args in argv if "--monitor-stream" in args]
                assert len(captures) == 1, argv
                assert captures[0][captures[0].index("--monitor-stream") + 1] == str(stream_id)
                assert captures[0][captures[0].index("--device") + 1] == sink + ".monitor"
                assert first_signal is not None and any(any(frame) for frame in frames), "no private audio captured"
                assert 50 < frame_count / duration < 70, "spectrum publication cadence changed"
            else:
                assert first_signal is None and all(not any(frame) for frame in frames), "unresolved identity captured audio"
            result = {"scenario": "active-private-audio" if active else "unresolved", "seconds": duration,
                      "tree_cpu_percent": 100 * (final_ticks - before_ticks) / TICKS / duration,
                      "tree_pss_kib_median": statistics.median(row["Pss"] for row in memories),
                      "tree_pss_kib_max": max(row["Pss"] for row in memories),
                      "tree_rss_kib_median": statistics.median(row["Rss"] for row in memories),
                      "parent_pss_kib": final_tree[process.pid]["memory"]["Pss"],
                      "first_frame_ms": first_frame * 1000 if first_frame is not None else None,
                      "first_signal_ms": first_signal * 1000 if first_signal is not None else None,
                      "frames": frame_count, "frames_per_second": frame_count / duration,
                      "frame_interval_ms_p95": percentile(intervals, .95),
                      "frame_interval_ms_max": max(intervals) if intervals else None,
                      "band_means": [statistics.mean(frame[i] for frame in frames) for i in range(24)] if frames else [],
                      "processes": len(final_tree), "stderr": buffers["stderr"].decode(errors="replace"),
                      "samples": memories}
        finally:
            observed_children.update(set(tree(process.pid)) - {process.pid})
            stop(process)
            process.stdout.close()
            process.stderr.close()
    # The helper must reap its children, not merely stop producing output.
    survivors = [pid for pid in observed_children if Path(f"/proc/{pid}").exists() and
                 Path(f"/proc/{pid}/stat").read_text().split(") ")[1].split()[0] != "Z"]
    assert not survivors, f"helper leaked children {survivors}"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rust", type=Path)
    parser.add_argument("--python", type=Path, default=ROOT / "bar/services/cava_stream.py")
    parser.add_argument("--seconds", type=float, default=12)
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert 1 <= args.rounds <= 5 and math.isfinite(args.seconds) and args.seconds >= 2
    defaults = pactl("get-default-sink"), pactl("get-default-source")
    identity = "isla-rust-benchmark-" + str(os.getpid())
    sink = identity.replace("-", "_")
    module = playback = None
    feeding = threading.Event()
    samples = []
    commands = {"python": [sys.executable, str(args.python.resolve())]}
    if args.rust:
        commands["rust"] = [str(args.rust.resolve())]
    try:
        module = pactl("load-module", "module-null-sink", "sink_name=" + sink,
                       "sink_properties=device.description=IslaRustBenchmark", "channels=2")
        assert defaults == (pactl("get-default-sink"), pactl("get-default-source")), "null sink changed user defaults"
        playback = subprocess.Popen(["pacat", "--playback", "--raw", "--format=s16le", "--rate=44100", "--channels=2",
                                     "--device=" + sink, "--latency-msec=20", "--property=application.name=" + identity],
                                    stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        tone = array("h", (int(6000 * math.sin(i * 2 * math.pi * 440 / 44100))
                           for i in range(4410) for _ in range(2))).tobytes()

        def feed():
            try:
                while not feeding.is_set():
                    playback.stdin.write(tone)
                    playback.stdin.flush()
                    feeding.wait(.1)
            except (OSError, ValueError):
                pass
        writer = threading.Thread(target=feed, daemon=True)
        writer.start()
        stream_id = None
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            streams = json.loads(pactl("-f", "json", "list", "sink-inputs"))
            target = [item for item in streams if (item.get("properties") or {}).get("application.name") == identity]
            if target:
                assert len(target) == 1
                stream_id = target[0]["index"]
                break
            time.sleep(.05)
        assert stream_id is not None, "private playback stream missing"
        for active in (False, True):
            for round_index in range(args.rounds):
                order = list(commands) if round_index % 2 == 0 else list(reversed(commands))
                for backend in order:
                    result = measure(commands[backend], identity if active else identity + "-absent", args.seconds,
                                     active, stream_id, sink)
                    result.update(backend=backend, round=round_index)
                    samples.append(result)
                    args.output.parent.mkdir(parents=True, exist_ok=True)
                    args.output.write_text(json.dumps({"samples": samples, "complete": False}, indent=2) + "\n")
                    print(backend, result["scenario"], "CPU%", round(result["tree_cpu_percent"], 3),
                          "tree PSS KiB", result["tree_pss_kib_median"], "fps", round(result["frames_per_second"], 2), flush=True)
    finally:
        feeding.set()
        stop(playback)
        if playback is not None:
            playback.stdin.close()
        if module is not None:
            pactl("unload-module", module)
        assert defaults == (pactl("get-default-sink"), pactl("get-default-source")), "user defaults changed"
    args.output.write_text(json.dumps({"samples": samples, "complete": True, "defaults_preserved": True,
                                     "scope": "helper plus descendants; excludes shared Pulse server and tone producer"}, indent=2) + "\n")
    print("PASS: frame protocol, exact private stream, cadence, child cleanup and unchanged defaults")


if __name__ == "__main__":
    main()
