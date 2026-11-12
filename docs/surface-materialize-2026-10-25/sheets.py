"""Contact sheets + measurements from capture.py output.

usage: sheets.py <before|after> <frames-dir>
Writes sheet-<scenario>.png (crop of the pill zone, time relative to the mark)
and metrics.json (geometry logged by the fixture, per scenario).
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw

label, frames = sys.argv[1], Path(sys.argv[2])
base = Path(__file__).resolve().parent / label
tl = json.loads((base / "timeline.json").read_text())
samples, marks, geo = tl["samples"], tl["marks"], tl["frames"]
CROP = (0, 0, 936, 700)
SC = 0.34
STEP_MS = 34
# (sheet name, mark that starts it, window ms)
SCEN = [("calendar-open", "calendar-open", 900), ("calendar-close", "calendar-close", 800),
        ("launcher-open", "launcher-open", 900), ("launcher-close", "launcher-close", 1000),
        ("mixer-open", "mixer-open", 900), ("mixer-close", "mixer-close", 800),
        ("switch-calendar-to-mixer", "switch-calendar-to-mixer", 900)]


def pick(t0, win):
    out, nxt = [], 0
    for s in samples:
        mid = (s["t0"] + s["t1"]) / 2
        rel = (mid - t0) * 1000
        if rel < -34 or rel > win: continue
        if rel >= nxt:
            out.append((rel, s["i"])); nxt = rel + STEP_MS
    return out


def geom_at(t):
    best = min(geo, key=lambda g: abs(g[0] - t)); return best


metrics = {}
for name, mark, win in SCEN:
    m = next(x for x in marks if x["name"] == mark)
    picks = pick(m["t"], win)
    cols = 6
    w, h = int((CROP[2] - CROP[0]) * SC), int((CROP[3] - CROP[1]) * SC)
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), "#10141a")
    d = ImageDraw.Draw(sheet)
    for k, (rel, i) in enumerate(picks):
        im = Image.open(frames / f"f{i:05d}.ppm").crop(CROP).resize((w, h), Image.LANCZOS)
        x, y = (k % cols) * w, (k // cols) * h
        sheet.paste(im, (x, y)); d.text((x + 4, y + 3), f"{rel:+.0f} ms", fill="#ffd166")
    sheet.save(base / f"sheet-{name}.png")
    series = [(round((g[0] - m["t"]) * 1000, 1), g[1], g[2], g[3], g[4], g[5]) for g in geo
              if -40 <= (g[0] - m["t"]) * 1000 <= win]
    metrics[name] = series
(base / "metrics.json").write_text(json.dumps(metrics))
print("ok", {k: len(v) for k, v in metrics.items()})
