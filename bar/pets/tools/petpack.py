#!/usr/bin/env python3
"""Eshell Pets package tool: validate a pet.json and build its runtime atlas.

    petpack.py validate <pack-dir>
    petpack.py build <pack-dir>

A package is data only: an indexed palette, frames as character grids and
animations that name those frames. The build writes atlas.png (one strip,
frames left to right in declaration order) and atlas.json (what the runtime
reads). The runtime never parses pet.json.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

FORMAT = 1
MAX_CANVAS = 32
MAX_FRAMES = 96
MAX_COLORS = 12
MAX_BYTES = 256 * 1024
MIN_MS, MAX_MS = 40, 5000
REQUIRED = ["idle", "blink", "look_left", "look_right", "look_up", "walk", "sit", "sleep", "react", "happy"]
# Optional animations fall back to a required one when a pack omits them.
FALLBACK = {"hop": "react", "yawn": "sleep", "code": "idle", "dance": "happy", "wave": "happy",
            "twirl": "happy", "sneeze": "react"}
ID = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def luminance(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def load(pack):
    path = Path(pack) / "pet.json"
    raw = path.read_bytes()
    if len(raw) > MAX_BYTES:
        raise ValueError(f"pet.json is {len(raw)} bytes; limit {MAX_BYTES}")
    return json.loads(raw), raw


def validate(data):
    """Return (errors, warnings). Errors make the pack unusable."""
    errors, warnings = [], []
    if data.get("format") != FORMAT:
        errors.append(f"format must be {FORMAT}")
    if not ID.match(str(data.get("id", ""))):
        errors.append("id must match " + ID.pattern)
    name = data.get("name")
    if not isinstance(name, str) or not 0 < len(name) <= 24:
        errors.append("name must be 1-24 characters")
    canvas = data.get("canvas") or {}
    w, h = canvas.get("width"), canvas.get("height")
    if not all(isinstance(v, int) and 8 <= v <= MAX_CANVAS for v in (w, h)):
        return errors + [f"canvas width/height must be integers 8-{MAX_CANVAS}"], warnings
    base = canvas.get("baseline")
    if not isinstance(base, int) or not 1 <= base <= h:
        errors.append("canvas.baseline must be a row inside the canvas")
    palette = data.get("palette") or {}
    if not 1 <= len(palette) <= MAX_COLORS:
        errors.append(f"palette needs 1-{MAX_COLORS} colours")
    for char, entry in palette.items():
        if len(char) != 1 or char == "." or not char.isprintable():
            errors.append(f"palette key {char!r} must be one printable character other than '.'")
        if not isinstance(entry, dict) or not COLOR.match(str(entry.get("color", ""))):
            errors.append(f"palette {char!r} needs color #rrggbb")
    variants = data.get("paletteVariants", {})
    if not isinstance(variants, dict):
        errors.append("paletteVariants must be an object")
        variants = {}
    for variant, overrides in variants.items():
        if not ID.fullmatch(variant) or variant == "marea" or not isinstance(overrides, dict):
            errors.append(f"palette variant {variant!r} is invalid")
            continue
        for char, color in overrides.items():
            if char not in palette or not isinstance(color, str) or not COLOR.fullmatch(color):
                errors.append(f"palette variant {variant!r}: invalid color for {char!r}")
        if "o" in overrides and overrides["o"].lower() != palette["o"]["color"].lower():
            errors.append(f"palette variant {variant!r}: outline must remain dark")
    if "o" in palette and COLOR.fullmatch(str(palette["o"].get("color", ""))):
        outline = luminance(palette["o"]["color"])
        for variant, overrides in {"marea": {}, **variants}.items():
            if not isinstance(overrides, dict):
                continue
            for char in ("b", "s", "h", "l", "d"):
                if char not in palette:
                    continue
                color = overrides.get(char, palette[char].get("color", ""))
                if isinstance(color, str) and COLOR.fullmatch(color):
                    darker, lighter = sorted((outline, luminance(color)))
                    if (lighter + 0.05) / (darker + 0.05) < 3:
                        warnings.append(f"palette {variant} {char}: low contrast against outline")
    frames = data.get("frames") or {}
    # Edge poses (sitting, sleeping) let the legs hang over the perch on purpose.
    hanging = {f for a in (data.get("animations") or {}).values()
               if isinstance(a, dict) and a.get("contact") == "edge" for f in a.get("frames") or []}
    if not 1 <= len(frames) <= MAX_FRAMES:
        errors.append(f"frames: 1-{MAX_FRAMES} required")
    for fname, rows in frames.items():
        if not isinstance(rows, list) or len(rows) != h or any(not isinstance(r, str) or len(r) != w for r in rows):
            errors.append(f"frame {fname}: must be {h} strings of {w} characters")
            continue
        bad = {c for r in rows for c in r if c != "." and c not in palette}
        if bad:
            errors.append(f"frame {fname}: unknown palette characters {sorted(bad)}")
        if fname not in hanging and isinstance(base, int) and base < h and any(c != "." for c in rows[base]):
            warnings.append(f"frame {fname}: pixels on the baseline row {base} sit below the perch")
    anims = data.get("animations") or {}
    for req in REQUIRED:
        if req not in anims:
            errors.append(f"missing required animation {req}")
    for aname, anim in anims.items():
        names, ms = anim.get("frames"), anim.get("ms")
        if not isinstance(names, list) or not names:
            errors.append(f"animation {aname}: frames must be a non-empty list")
            continue
        if not isinstance(ms, list) or len(ms) != len(names):
            errors.append(f"animation {aname}: ms must match frames")
            continue
        for fname in names:
            if fname not in frames:
                errors.append(f"animation {aname}: unknown frame {fname}")
        for value in ms:
            if not isinstance(value, int) or not MIN_MS <= value <= MAX_MS:
                errors.append(f"animation {aname}: durations must be integers {MIN_MS}-{MAX_MS}")
                break
    for event, aname in (data.get("events") or {}).items():
        if aname not in anims and aname not in FALLBACK:
            errors.append(f"event {event}: unknown animation {aname}")
    for entry in data.get("mischief") or []:
        if entry.get("animation") not in anims:
            errors.append(f"mischief: unknown animation {entry.get('animation')}")
    text = json.dumps(data)
    if re.search(r"(https?:|file:|\.\./|javascript:)", text):
        errors.append("packages may not contain URLs or paths")
    return errors, warnings


def hit_box(rows, baseline):
    """Opaque bounds above the feet row: the pet's clickable body."""
    top = [y for y, r in enumerate(rows[:max(0, baseline - 1)]) if r.strip(".")]
    xs = [x for r in rows[:max(0, baseline - 1)] for x, c in enumerate(r) if c != "."]
    if not top:
        return [0, 0, len(rows[0]), baseline]
    return [min(xs), min(top), max(xs) - min(xs) + 1, max(top) - min(top) + 1]


def build(pack):
    from PIL import Image
    data, raw = load(pack)
    errors, warnings = validate(data)
    for line in warnings:
        print("warning:", line, file=sys.stderr)
    if errors:
        raise SystemExit("invalid package:\n  " + "\n  ".join(errors))
    w, h = data["canvas"]["width"], data["canvas"]["height"]
    names = list(data["frames"])
    index = {name: i for i, name in enumerate(names)}
    out = Path(pack)
    for variant, overrides in {"marea": {}, **data.get("paletteVariants", {})}.items():
        colors = {c: tuple(int(overrides.get(c, e["color"])[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
                  for c, e in data["palette"].items()}
        atlas = Image.new("RGBA", (w * len(names), h), (0, 0, 0, 0))
        for i, name in enumerate(names):
            for y, row in enumerate(data["frames"][name]):
                for x, c in enumerate(row):
                    if c != ".":
                        atlas.putpixel((i * w + x, y), colors[c])
        atlas.save(out / ("atlas.png" if variant == "marea" else f"atlas-{variant}.png"), optimize=True)
    anims = {name: {"f": [index[f] for f in a["frames"]], "ms": a["ms"], "loop": bool(a.get("loop")),
                    "stepPx": int(a.get("stepPx", 0)), "settleAfterLoops": int(a.get("settleAfterLoops", 0)),
                    "edge": a.get("contact") == "edge"}
             for name, a in data["animations"].items()}
    for name, fallback in FALLBACK.items():
        anims.setdefault(name, anims[fallback])
    baseline = data["canvas"]["baseline"]
    # Union of every opaque pixel: how far any pose reaches past the body.
    cells = [(x, y) for rows in data["frames"].values() for y, r in enumerate(rows) for x, c in enumerate(r) if c != "."]
    bounds = [min(x for x, _ in cells), min(y for _, y in cells),
              max(x for x, _ in cells) + 1, max(y for _, y in cells) + 1]
    manifest = {"format": FORMAT, "id": data["id"], "name": data["name"],
                "canvas": {"width": w, "height": h, "baseline": baseline,
                           "originX": data["canvas"].get("originX", w // 2)},
                "frameCount": len(names), "hit": hit_box(data["frames"]["idle_0"] if "idle_0" in data["frames"]
                                                          else data["frames"][names[0]], baseline),
                "bounds": bounds,
                "animations": anims, "events": data.get("events", {}),
                "paletteVariants": list(data.get("paletteVariants", {})),
                "mischief": data.get("mischief", []),
                "source": hashlib.sha256(raw).hexdigest()}
    (out / "atlas.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    print(f"built {data['id']}: {len(names)} frames, atlas {atlas.width}x{atlas.height}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["validate", "build"])
    parser.add_argument("pack")
    args = parser.parse_args()
    if args.command == "build":
        build(args.pack)
        return
    data, _ = load(args.pack)
    errors, warnings = validate(data)
    for line in warnings:
        print("warning:", line)
    for line in errors:
        print("error:", line)
    print("PASS" if not errors else "FAIL")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
