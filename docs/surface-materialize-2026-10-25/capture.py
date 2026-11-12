"""Native Wayland sampling of bar/surface-materialize-capture.qml.

usage: capture.py <before|after> <scratch-dir>

grim is run back to back on the window area while the fixture drives the
production Pill. Samples are irregular: each one is stamped with the epoch time
it was taken (start/end of the grim call) and matched later to the per-frame
geometry the fixture logs (MAT_F). Frames are PPM files in <scratch-dir>.
"""
import json, os, subprocess, sys, tempfile, threading, time
from pathlib import Path

label, scratch = sys.argv[1], Path(sys.argv[2])
scratch.mkdir(parents=True, exist_ok=True)
out = Path(__file__).resolve().parent / label
root = Path(__file__).resolve().parents[2]


def window_geometry():
    clients = json.loads(subprocess.run(["hyprctl", "-j", "clients"], check=True, capture_output=True, text=True).stdout)
    for c in clients:
        if "materialización" in c.get("title", ""):
            return c["at"], c["size"]
    return None, None


stop = threading.Event()
samples = []


def grab_loop(geom):
    i = 0
    while not stop.is_set():
        t0 = time.time()
        path = scratch / f"f{i:05d}.ppm"
        subprocess.run(["grim", "-t", "ppm", "-g", geom, str(path)], check=True)
        t1 = time.time()
        samples.append({"i": i, "t0": t0, "t1": t1})
        i += 1


with tempfile.TemporaryDirectory(prefix="isla-materialize-") as tmp:
    Path(tmp, "iris").mkdir()
    env = dict(os.environ, ISLA_CONFIG=tmp + "/config.json", ISLA_IRIS=tmp + "/iris/iris.json",
               ISLA_TEST_OUTPUT="1", QT_QPA_PLATFORM="wayland")
    proc = subprocess.Popen(["timeout", "120s", "quickshell", "-p", "bar/surface-materialize-capture.qml"], cwd=root,
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    frames, marks, thread, geom_line = [], [], None, None
    for line in proc.stdout:
        if line.startswith("MAT_F") or "MAT_F " in line:
            p = line.split("MAT_F ")[1].split()
            frames.append([float(x) for x in p])
        elif "MAT_MARK " in line:
            p = line.split("MAT_MARK ")[1].split()
            marks.append({"t": float(p[0]) / 1000, "name": p[1]})
        elif "MAT_GEOM " in line:
            geom_line = [float(x) for x in line.split("MAT_GEOM ")[1].split()]
        elif "MAT_START" in line:
            at, size = window_geometry()
            if not at:
                print("window not found"); proc.kill(); raise SystemExit(1)
            geom = f"{at[0]},{at[1]} {size[0]}x{size[1]}"
            print("window", geom, "pill", geom_line, flush=True)
            thread = threading.Thread(target=grab_loop, args=(geom,)); thread.start()
        elif "MAT_END" in line:
            stop.set()
        elif "WARN" in line or "ERROR" in line or "FAIL" in line:
            print(line.rstrip())
    proc.wait(); stop.set()
    if thread: thread.join()
    out.mkdir(parents=True, exist_ok=True)
    (out / "timeline.json").write_text(json.dumps({
        "window": geom, "pill": geom_line, "marks": marks,
        "samples": samples, "frames": [[f[0] / 1000] + f[1:] for f in frames]}))
    print("samples", len(samples), "frames", len(frames), "marks", len(marks))
