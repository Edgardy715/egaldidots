#!/usr/bin/env python3
"""Explorer performance with 20 000 files: open (cold/warm), scroll, navigate x20, RSS after close.

Three passes over a copy of bar/ in a temporary directory (the fixture lives there too and is always
removed):
  0. cold pass: a new process with QML_DISABLE_DISK_CACHE=1, only its first open is kept;
  1. timing pass: the harness measures with Date.now() (4 ms polling) and prints METRIC lines. Its
     first open is the first in a new process (disk cache warm), the second reuses the process;
  2. profiler pass (a failure makes the exit code non-zero): the same harness under `qs --debug PORT --waitfordebug` with
     `/usr/bin/qmlprofiler --attach`, summarised by type (creating, binding, javascript...).
Offscreen (default) renders no real frames: the "frame" intervals are the animation driver's ticks
(FrameAnimation.frameTime), not FPS. Use --platform wayland for a real compositor run.
Writes JSON to --output (default /tmp/isla-files-performance-<time>.json).
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PROFILER = Path("/usr/bin/qmlprofiler")
TRACE_PARSER = Path.home() / ".agents/skills/qt-qml-profiler/references/scripts/parse-qmlprofiler-trace.py"
FILES = 20000

HARNESS = r'''
import QtQuick
import Quickshell
import Quickshell.Io
import "components/files"
import "Singletons"

ShellRoot {
    id: suite
    settings.watchFiles: false
    readonly property string base: Quickshell.env("ISLA_FILES_PERF_ROOT")
    property var view: null
    property string rss: ""
    property bool rssDone: false
    Process {
        id: rssProc
        command: ["sh", "-c", "grep VmRSS /proc/$PPID/status"]
        stdout: StdioCollector { onStreamFinished: { suite.rss = text.trim(); suite.rssDone = true } }
    }
    function metric(name, value) { console.log("METRIC " + JSON.stringify({ name: name, value: value })) }
    Component { id: viewComponent; FilesView { anchors.fill: parent } }
    // Driver tick intervals (ms) while sampling; offscreen these are timer ticks, not rendered frames.
    property var ticks: []
    property bool sampling: false
    FrameAnimation { running: suite.sampling; onTriggered: suite.ticks.push(frameTime * 1000) }

    Window {
        id: window
        visible: true
        width: 1000
        height: 660
        color: Theme.background
        Item { id: host; anchors.fill: parent }
    }

    property int phase: 0
    property double t0: 0
    property var navTimes: []
    property var navModelTimes: []
    property int navIndex: 0
    property int scrollStep: 0
    function findLoader(item) {
        if (item.objectName === "viewLoader") return item.item
        for (const c of item.children || []) { const hit = findLoader(c); if (hit) return hit }
        return null
    }
    // The grid is looked up once per open (no tree walk per tick).
    property var _grid: null
    function gridItem() { if (!_grid && view) _grid = findLoader(view); return _grid }
    function delegates() {
        const g = gridItem()
        if (!g || !g.flick) return 0
        return g.flick.contentItem.children.filter(c => c.objectName === "fileDelegate" && c.visible).length
    }
    function open() {
        _grid = null; _firstAt = 0; _modelAt = 0
        t0 = Date.now()
        view = viewComponent.createObject(host, { startPath: base + "/big" })
    }
    function close() { view.destroy(); view = null; _grid = null; gc() }

    Timer {
        id: tick
        // 4 ms polling (16 ms under the profiler); the handler only reads a few properties.
        interval: Quickshell.env("ISLA_FILES_PERF_PROFILE") === "1" ? 16 : 4
        repeat: true
        running: suite.base.length > 0 && Config.loaded
        property double phaseStart: 0
        onTriggered: {
            const now = Date.now()
            if (now - suite.t0 > 60000 && suite.phase > 0) { console.error("FAIL: perf phase " + suite.phase + " timeout"); Qt.exit(1) }
            switch (suite.phase) {
            case 0:
                FileOps.environment = { XDG_DATA_HOME: suite.base + "/data" }
                suite.t0 = now; rssProc.running = true; suite.phase = 1; break
            case 1:
                if (!suite.rssDone) return
                suite.metric("rss_before_open", suite.rss); suite.rssDone = false
                suite.open(); suite.phase = 2; break
            case 2: case 4:
                // open: model ready, then the first delegates and the end of the opening spring
                // three separate marks: listing ready, first delegate built, opening spring settled
                if (!suite._firstAt && suite.gridItem() && suite.gridItem().createdCount > 0) suite._firstAt = now
                if (!suite.view.model.ready || suite.view.model.count < 20000) return
                if (!suite._modelAt) suite._modelAt = now
                if (!suite._firstAt || suite.view.opening) return
                suite.metric(suite.phase === 2 ? "open_first_in_process" : "open_second_in_process", { model_ready_ms: suite._modelAt - suite.t0, first_delegate_ms: suite._firstAt - suite.t0, spring_settled_ms: now - suite.t0, delegates: suite.delegates(), resolution_ms: tick.interval })
                suite._modelAt = 0; suite._firstAt = 0
                if (suite.phase === 2) { suite.close(); suite.t0 = Date.now(); suite.open(); suite.phase = 4 }
                else { suite.phase = 5; suite.ticks = []; suite.sampling = true; suite.scrollStep = 0; suite.t0 = now }
                break
            case 5: {
                // scroll the whole grid in 240 steps, one per tick
                const g = suite.gridItem()
                const f = g.flick
                const span = Math.max(0, f.contentHeight - f.height)
                f.contentY = span * suite.scrollStep / 240
                if (++suite.scrollStep > 240) {
                    suite.sampling = false
                    suite.metric("scroll", { steps: 240, content_height: f.contentHeight, ms: now - suite.t0, tick_ms: suite.ticks, delegates_after: suite.delegates() })
                    f.contentY = 0
                    suite.phase = 6; suite.navIndex = 0; suite.t0 = now; suite._navStart = 0
                    suite.ticks = []; suite.sampling = true
                }
                break
            }
            case 6: {
                // navigate x20: big -> small -> big ... measured to the model listing and to the settled view
                const target = suite.navIndex % 2 === 0 ? suite.base + "/small" : suite.base + "/big"
                if (!suite._navStart) { suite._navStart = now; suite._navModel = 0; suite.view.navigate(target); return }
                if (suite.view.path !== target || !suite.view.model.ready) return
                const want = target.endsWith("/big") ? 20000 : 5
                if (suite.view.model.count !== want) return
                if (!suite._navModel) suite._navModel = now
                if (suite.view.animating) return
                suite.navModelTimes.push(suite._navModel - suite._navStart)
                suite.navTimes.push(now - suite._navStart)
                suite._navStart = 0
                if (++suite.navIndex >= 20) {
                    suite.sampling = false
                    suite.metric("navigate", { count: 20, model_ready_ms: suite.navModelTimes, settled_ms: suite.navTimes, tick_ms: suite.ticks })
                    suite.close(); suite.phase = 7; suite.t0 = now
                }
                break
            }
            case 7:
                if (now - suite.t0 < 500) return
                gc(); rssProc.running = true; suite.phase = 8; break
            case 8:
                if (!suite.rssDone) return
                suite.metric("rss_after_close", suite.rss)
                suite.phase = 9
                console.log("PERF_DONE")
                Qt.quit()
                break
            }
        }
    }
    property double _modelAt: 0
    property double _firstAt: 0
    property double _navStart: 0
    property double _navModel: 0
}
'''


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def pct(values, p):
    if not values: return None
    ordered = sorted(values)
    return round(ordered[min(len(ordered) - 1, max(0, int(round(p * (len(ordered) - 1)))))], 2)


def summarize_ticks(ticks):
    ticks = [t for t in ticks if t > 0]
    if not ticks: return {"count": 0}
    return {"count": len(ticks), "p50_ms": pct(ticks, 0.5), "p95_ms": pct(ticks, 0.95), "max_ms": round(max(ticks), 2)}


def by_file(trace):
    """Inclusive ms per QML file and range type (nested ranges overlap: compare files, do not add them)."""
    import xml.etree.ElementTree as ET
    root = ET.parse(trace).getroot()
    files = {}
    for ev in root.find("eventData"):
        files[int(ev.get("index"))] = ((ev.findtext("filename") or "").rsplit("/", 1)[-1], ev.findtext("type") or "")
    totals = {}
    model = root.find("profilerDataModel")
    for r in (model if model is not None else []):
        if r.get("duration") is None or r.get("eventIndex") is None: continue
        name, kind = files.get(int(r.get("eventIndex")), ("", ""))
        if not name or kind not in ("Binding", "Javascript", "Creating", "HandlingSignal"): continue
        key = name + ":" + kind
        totals[key] = totals.get(key, 0) + int(r.get("duration")) / 1e6
    return dict(sorted(((k, round(v, 1)) for k, v in totals.items()), key=lambda kv: -kv[1])[:40])


def parse_metrics(log):
    metrics = {}
    for line in log.splitlines():
        at = line.find("METRIC ")
        if at >= 0:
            item = json.loads(line[at + 7:])
            metrics[item["name"]] = item["value"]
    return metrics


def run_pass(work, env, profile, timeout):
    command = ["qs", "-p", str(work / "bar/files-performance-harness.qml")]
    trace = work / "trace.qtd"
    prof = None
    if profile:
        port = free_port()
        command = ["qs", "--debug", str(port), "--waitfordebug", "-p", str(work / "bar/files-performance-harness.qml")]
    app = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        if profile:
            time.sleep(1.0)
            prof = subprocess.Popen([str(PROFILER), "--attach", "localhost", "-p", str(port), "-o", str(trace)],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        out, _ = app.communicate(timeout=timeout)
        prof_out = prof.communicate(timeout=60)[0] if prof else ""
    finally:
        for p in (app, prof):
            if p and p.poll() is None:
                p.kill(); p.wait()
    return app.returncode, out, prof_out, trace


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=Path("/tmp") / time.strftime("isla-files-performance-%Y%m%d-%H%M%S.json"))
    parser.add_argument("--platform", default="offscreen", choices=("offscreen", "wayland"))
    parser.add_argument("--no-profile", action="store_true", help="skip the qmlprofiler pass")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    profile_failed = ""
    result = {"files": FILES, "platform": args.platform,
              "note": "offscreen: tick_ms are animation-driver ticks (no rendered frames), not FPS" if args.platform == "offscreen" else "wayland run"}
    with tempfile.TemporaryDirectory(prefix="isla-files-perf-") as directory:
        work = Path(directory)
        try:
            shutil.copytree(ROOT / "bar", work / "bar", ignore=shutil.ignore_patterns("__pycache__", "tests"))
            (work / "bar/files-performance-harness.qml").write_text(HARNESS)
            fixture = work / "fixture"
            for sub in ("big", "small", "data"): (fixture / sub).mkdir(parents=True)
            for i in range(FILES): (fixture / "big" / f"file-{i:05d}.txt").write_bytes(b"x")
            for i in range(5): (fixture / "small" / f"s{i}.txt").write_bytes(b"x")
            config = work / "config.json"
            config.write_text("{}")
            env = {**os.environ, "ISLA_CONFIG": str(config), "XDG_STATE_HOME": str(work / "state"),
                   "ISLA_FILES_PERF_ROOT": str(fixture), "QT_QPA_PLATFORM": args.platform}
            # Truly cold compile: a new process with the QML disk cache disabled (first open only).
            rc0, out0, _, _ = run_pass(work, {**env, "QML_DISABLE_DISK_CACHE": "1"}, False, args.timeout)
            if rc0 != 0 or "PERF_DONE" not in out0:
                print("FAIL: cold pass rc=%s" % rc0)
                return 1
            cold = parse_metrics(out0).get("open_first_in_process")
            rc, out, _, _ = run_pass(work, env, False, args.timeout)
            metrics = parse_metrics(out)
            metrics["open_cold_new_process_no_disk_cache"] = cold
            if rc != 0 or "PERF_DONE" not in out:
                print("FAIL: timing pass rc=%s" % rc)
                print("\n".join(l for l in out.splitlines() if "FAIL" in l or "rror" in l)[-2000:])
                return 1
            for key in ("scroll", "navigate"):
                if key in metrics:
                    metrics[key]["ticks"] = summarize_ticks(metrics[key].pop("tick_ms", []))
            nav = metrics.get("navigate", {})
            big = [t for i, t in enumerate(nav.get("model_ready_ms", [])) if i % 2 == 1]
            small = [t for i, t in enumerate(nav.get("model_ready_ms", [])) if i % 2 == 0]
            nav["model_ready_big_median_ms"] = statistics.median(big) if big else None
            nav["model_ready_small_median_ms"] = statistics.median(small) if small else None
            nav["settled_p95_ms"] = pct(nav.get("settled_ms", []), 0.95)
            result["timing"] = metrics
            if not args.no_profile:
                if not PROFILER.exists():
                    result["profile"] = {"error": "qmlprofiler not found"}
                else:
                    rc2, out2, prof_out, trace = run_pass(work, {**env, "ISLA_FILES_PERF_PROFILE": "1"}, True, args.timeout)
                    profile = {"rc": rc2, "trace_bytes": trace.stat().st_size if trace.exists() else 0}
                    if trace.exists() and TRACE_PARSER.exists():
                        parsed = subprocess.run([sys.executable, str(TRACE_PARSER), str(trace)], capture_output=True, text=True)
                        try:
                            summary = json.loads(parsed.stdout)
                            profile["by_type"] = summary.get("by_type")
                            profile["hotspots"] = (summary.get("hotspots") or [])[:30]
                            profile["animations"] = summary.get("animations")
                            profile["memory"] = summary.get("memory")
                        except json.JSONDecodeError:
                            profile["error"] = "trace parser output: " + parsed.stderr[-400:]
                    elif not trace.exists():
                        profile["error"] = "no trace recorded: " + prof_out[-400:]
                    else:
                        profile["error"] = "trace parser not found at " + str(TRACE_PARSER)
                    if trace.exists():
                        profile["by_file"] = by_file(trace)
                    profile["timing_under_profiler"] = parse_metrics(out2).get("open_first_in_process")
                    if rc2 != 0 or "PERF_DONE" not in out2 or "error" in profile:
                        profile_failed = "rc=%s %s" % (rc2, profile.get("error", "harness did not finish"))
                    result["profile"] = profile
        finally:
            shutil.rmtree(work / "fixture", ignore_errors=True)
    args.output.write_text(json.dumps(result, indent=2))
    if profile_failed:
        print("FAIL: profiler pass " + profile_failed + " (timing saved in " + str(args.output) + ")")
        return 1
    t = result["timing"]
    print("PASS: files performance (%d files, %s) -> %s" % (FILES, args.platform, args.output))
    print("  open cold (new process, no QML disk cache) %s" % t.get("open_cold_new_process_no_disk_cache"))
    print("  open first in process %s | second %s" % (t.get("open_first_in_process"), t.get("open_second_in_process")))
    print("  scroll ticks %s" % t.get("scroll", {}).get("ticks"))
    print("  navigate model big/small median %s/%s ms, settled p95 %s ms" % (nav.get("model_ready_big_median_ms"), nav.get("model_ready_small_median_ms"), nav.get("settled_p95_ms")))
    print("  rss before %s | after close %s" % (t.get("rss_before_open"), t.get("rss_after_close")))
    if "profile" in result:
        print("  profile by type %s" % json.dumps(result["profile"].get("by_type") or result["profile"].get("error")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
