#!/usr/bin/env python3
"""Private CLI and QML data-readiness comparison; never reads the user library."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "docs/rust-clipboard-list-2026-10-21/baseline"
fixture = runpy.run_path(str(ROOT / "bar/tests/clipboard-list.py"))["fixture"]


def timed(command, env):
    # A regular output fd avoids pipe backpressure while wait4 collects per-child CPU/RSS.
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as error:
        start = time.monotonic()
        process = subprocess.Popen(command, env=env, stdout=output, stderr=error)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        output.seek(0)
        result = json.load(output)
        wall = (time.monotonic() - start) * 1000
        error.seek(0)
        assert process.returncode == 0 and result["ok"], (result, error.read())
        return {"wall_ms": wall, "cpu_ms": 1000 * (usage.ru_utime + usage.ru_stime),
                }, result["data"]


def profile_pss(command, env):
    # Separate from timing: sampling a short-lived process can perturb its duration.
    samples = []
    parent_stat = Path("/proc/self/stat").read_text()
    parent_stack = parent_stat[parent_stat.rindex(")") + 2:].split()[25]
    observed_rss = []
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as error:
        process = subprocess.Popen(command, env=env, stdout=output, stderr=error)
        try:
            while process.poll() is None:
                try:
                    path = Path("/proc") / str(process.pid)
                    stat = (path / "stat").read_text()
                    stack = stat[stat.rindex(")") + 2:].split()[25]
                    # Exclude the inherited Python image before exec, even with the same executable.
                    if stack != parent_stack and (path / "exe").resolve() == Path(command[0]).resolve():
                        for line in (path / "smaps_rollup").read_text().splitlines():
                            if line.startswith("Pss:"):
                                samples.append(int(line.split()[1]))
                        for line in (path / "status").read_text().splitlines():
                            if line.startswith("VmHWM:"):
                                observed_rss.append(int(line.split()[1]))
                except (FileNotFoundError, ProcessLookupError):
                    pass
                time.sleep(.0005)
            assert process.returncode == 0
        finally:
            if process.poll() is None: process.kill()
            process.wait()
    return samples, max(observed_rss) if observed_rss else None


def qml_run(bar, env, count, rounds):
    source = '''import QtQuick
import Quickshell
import "components"
ShellRoot {
    settings.watchFiles: false
    property double begun: 0
    property var times: []
    ClipboardController {
        id: clipboard
        section: "saved"
        onLibraryBusyChanged: if (!libraryBusy && begun) Qt.callLater(finish)
    }
    function finish() {
        if (clipboard.errorMessage || clipboard.savedEntries.length !== COUNT) {
            console.error("FAIL: readiness", clipboard.errorMessage); Qt.exit(1); return
        }
        times.push(Date.now() - begun)
        begun = 0
        if (times.length === ROUNDS) {
            console.log("CLIPBOARD_TIMING " + JSON.stringify(times)); Qt.quit()
        } else next.start()
    }
    Timer {
        id: next; interval: 20; running: true
        onTriggered: { begun = Date.now(); clipboard.loadLibrary() }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("FAIL: timeout"); Qt.exit(1) } }
}
'''.replace("COUNT", str(count)).replace("ROUNDS", str(rounds))
    target = bar / "clipboard-timing.qml"
    target.write_text(source)
    result = subprocess.run(["qs", "-p", str(target)], env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "CLIPBOARD_TIMING " in output, output
    line = next(line for line in output.splitlines() if "CLIPBOARD_TIMING " in line)
    values = json.loads(line.split("CLIPBOARD_TIMING ", 1)[1])
    assert len(values) == rounds and all(0 <= value < 12000 for value in values), values
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert 4 <= args.rounds <= 50
    result = {"cli": [], "qml": [], "pss": [], "complete": False,
              "scope": "fresh list request with private synthetic metadata; excludes whole-shell startup"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="isla-clipboard-perf-") as tmp:
        temp = Path(tmp)
        library = temp / "library"
        library.mkdir()
        data_home = temp / "data"
        native = data_home / "isla/bin/isla-clipboard-list"
        native.parent.mkdir(parents=True)
        shutil.copy2(args.binary, native)
        bars = {}
        for backend in ("python", "rust"):
            bars[backend] = temp / backend / "bar"
            shutil.copytree(ROOT / "bar", bars[backend], ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(BASELINE / "bar/components/ClipboardController.qml", bars["python"] / "components")
        # Both variants must use exactly the frozen Python writes/metadata contract.
        for bar in bars.values():
            shutil.copy2(BASELINE / "bar/services/clipboard_library.py", bar / "services")
        config = temp / "config.json"
        config.write_text("{}")
        env = {**os.environ, "ISLA_CLIPBOARD_LIBRARY": str(library), "XDG_DATA_HOME": str(data_home),
               "XDG_CACHE_HOME": str(temp / "cache"), "ISLA_CONFIG": str(config), "QT_QPA_PLATFORM": "offscreen"}
        commands = {"python": [sys.executable, str(BASELINE / "bar/services/clipboard_library.py"), "list"],
                    "rust": [str(native), "list", "--fallback", str(BASELINE / "bar/services/clipboard_library.py")]}
        for count in (0, 100, 1000):
            data = fixture(count)
            for item in data["entries"]:
                (library / (item["id"] + ".bin")).write_bytes(b"synthetic payload")
            metadata = library / "library.json"
            metadata.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            before = hashlib.sha256(metadata.read_bytes()).hexdigest()
            for command in commands.values():
                _, decoded = timed(command, env)
                assert decoded == data
            for round_index in range(args.rounds):
                for backend in (list(commands) if round_index % 2 == 0 else list(reversed(commands))):
                    row, decoded = timed(commands[backend], env)
                    assert decoded == data
                    row.update(backend=backend, count=count, round=round_index)
                    result["cli"].append(row)
            for round_index in range(4):
                for backend in (list(commands) if round_index % 2 == 0 else list(reversed(commands))):
                    samples, peak_rss = profile_pss(commands[backend], env)
                    result["pss"].append(dict(backend=backend, count=count, round=round_index,
                                              samples_kib=samples, observed_rss_hwm_kib=peak_rss,
                                              observed_peak_kib=max(samples) if samples else None))
            for round_index in range(2):
                for backend in (list(bars) if round_index % 2 == 0 else list(reversed(bars))):
                    times = qml_run(bars[backend], env, count, 10)
                    result["qml"].append(dict(backend=backend, count=count, round=round_index, readiness_ms=times))
            assert hashlib.sha256(metadata.read_bytes()).hexdigest() == before, "metadata changed"
            args.output.write_text(json.dumps(result, indent=2) + "\n")
            print("entries", count, "CLI median ms", {b: round(statistics.median(r["wall_ms"] for r in result["cli"]
                  if r["backend"] == b and r["count"] == count), 2) for b in commands}, flush=True)
        result["complete"] = True
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: equal private data, alternating CLI/QML, metadata unchanged")


if __name__ == "__main__":
    main()
