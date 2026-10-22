#!/usr/bin/env python3
"""Alternate isolated Wayland navigation fixtures; optional lazy-editor invariant."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "docs/settings-latency-2026-10-22/baseline"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--rounds", type=int, default=3)
parser.add_argument("--baseline-lazy-check", action="store_true")
args = parser.parse_args()
assert 1 <= args.rounds <= 5
results = []
with tempfile.TemporaryDirectory(prefix="isla-settings-navigation-") as directory:
    temp = Path(directory)
    for backend in ("before", "after"):
        bar = temp / backend / "bar"
        shutil.copytree(ROOT / "bar", bar, ignore=shutil.ignore_patterns("__pycache__"))
        if backend == "before":
            for source in (BASELINE / "bar").rglob("*"):
                if source.is_file(): shutil.copy2(source, bar / source.relative_to(BASELINE / "bar"))
            # Test-only names permit the same invariant to catch instantiated hidden controls.
            source = bar / "settings/SettingRow.qml"
            text = source.read_text()
            for name, marker in (("toggle", "settingToggle"), ("slider", "settingSlider"), ("textEditor", "settingTextEditor")):
                text = text.replace("id: " + name + "\n", "id: " + name + '\n                objectName: "' + marker + '"\n')
            source.write_text(text)
        source = bar / "Singletons/Config.qml"
        text = source.read_text().replace("    function snapshot() {", "    property var fixtureCounters: ({snapshots: 0, validations: 0})\n    function snapshot() { fixtureCounters.snapshots++;")
        text = text.replace("function validate(document) { return", "function validate(document) { fixtureCounters.validations++; return")
        source.write_text(text)
        fixture = bar / "settings-navigation-regression.qml"
        text = fixture.read_text().replace('import "settings"', 'import "settings"\nimport "Singletons/Settings.js" as Settings')
        text = text.replace('                const observedCounts = []', '''                const document = Config.snapshot().document
                const timings = []
                for (let sample = 0; sample < 10; sample++) {
                    const start = Date.now()
                    for (let i = 0; i < 100; i++) {
                        Settings.validate(Settings.merge(document, {appearance:{glassAlpha:0.6}}), Config.context)
                    }
                    timings.push((Date.now() - start) / 100)
                }
                console.log("CONFIG_TIMING " + JSON.stringify(timings))
                const observedCounts = []''')
        text = text.replace('                        editor.page = destination', '''                        Config.fixtureCounters.snapshots = 0
                        Config.fixtureCounters.validations = 0
                        editor.page = destination''')
        text = text.replace('                        if (destination === 1)', '''                        console.log("CONFIG_CALLS " + JSON.stringify(Config.fixtureCounters))
                        if (Quickshell.env("ISLA_ASSERT_LAZY") === "1") {
                            const inspect = function(item) {
                                if (item.fieldKey !== undefined && item.submitText !== undefined) {
                                    if (!!findChild(item, "settingToggle") !== (item.field.control === "toggle")) console.error("LAZY_EDITOR_FAIL only applicable toggle: " + item.fieldKey)
                                    compare(!!findChild(item, "settingToggle"), item.field.control === "toggle", "only applicable toggle: " + item.fieldKey)
                                    if (!!findChild(item, "settingSlider") !== item.ranged) console.error("LAZY_EDITOR_FAIL only applicable slider: " + item.fieldKey)
                                    compare(!!findChild(item, "settingSlider"), item.ranged, "only applicable slider: " + item.fieldKey)
                                    const textExpected = (item.field.control === "text" && !item.fontField) || item.field.control === "path" || (item.field.type === "number" && !item.ranged)
                                    if (!!findChild(item, "settingTextEditor") !== textExpected) console.error("LAZY_EDITOR_FAIL only applicable text: " + item.fieldKey)
                                    compare(!!findChild(item, "settingTextEditor"), textExpected, "only applicable text: " + item.fieldKey)
                                }
                                for (const child of item.children || []) inspect(child)
                            }
                            inspect(page)
                        }
                        if (destination === 1)''')
        fixture.write_text(text)
    for round_index in range(args.rounds):
        for backend in (("before", "after") if round_index % 2 == 0 else ("after", "before")):
            if args.baseline_lazy_check and backend == "after": continue
            work = temp / backend
            config = work / "config.json"
            config.write_text("{}")
            env = {**os.environ, "ISLA_CONFIG": str(config), "XDG_STATE_HOME": str(work / "state"),
                   "QT_QPA_PLATFORM": "wayland", "ISLA_ASSERT_LAZY": "1" if backend == "after" or args.baseline_lazy_check else "0"}
            result = subprocess.run(["timeout", "30s", "qs", "-p", str(work / "bar/settings-navigation-regression.qml")],
                                    env=env, capture_output=True, text=True, timeout=35)
            output = result.stdout + result.stderr
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.with_name(args.output.stem + f"-{backend}-{round_index}.txt").write_text(output)
            if args.baseline_lazy_check:
                assert "only applicable" in output and ("FAIL" in output or result.returncode != 0), output
                print("PASS: baseline reproduces hidden-editor invariant failure")
                break
            assert result.returncode == 0 and "PASS: settings navigation" in output and "FAIL" not in output, output
            metrics = [dict(page=int(page), cycle=int(cycle), max_ms=int(gap)) for page, cycle, gap in
                       re.findall(r"METRIC: page=(\d+) cycle=(\d+) maxms=(\d+)", output)]
            calls = [json.loads(line.split("CONFIG_CALLS ", 1)[1]) for line in output.splitlines() if "CONFIG_CALLS " in line]
            qt_times = json.loads(next(line.split("CONFIG_TIMING ", 1)[1] for line in output.splitlines() if "CONFIG_TIMING " in line))
            assert len(metrics) == 12 and len(calls) == 12 and len(qt_times) == 10
            results.append(dict(backend=backend, round=round_index, metrics=metrics, config_calls=calls, qt_update_core_ms=qt_times))
            args.output.write_text(json.dumps({"complete": False, "runs": results}, indent=2) + "\n")
            print(backend, round_index, "max gap", max(row["max_ms"] for row in metrics), "config calls", calls, flush=True)
    args.output.write_text(json.dumps({"complete": True, "runs": results}, indent=2) + "\n")
