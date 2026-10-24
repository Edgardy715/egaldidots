#!/usr/bin/env python3
"""Eshell Pets checks: package validity and freshness, runtime offscreen, composition on Wayland."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PACKS = ROOT / "bar/pets/packs"
TOOL = ROOT / "bar/pets/tools/petpack.py"


def check_packs():
    for pack in sorted(path for path in PACKS.iterdir() if (path / "pet.json").exists()):
        result = subprocess.run([sys.executable, "-I", str(TOOL), "validate", str(pack)], capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(f"FAIL: {pack.name} invalid: {result.stdout}{result.stderr}")
        atlas = json.loads((pack / "atlas.json").read_text())
        source = hashlib.sha256((pack / "pet.json").read_bytes()).hexdigest()
        if atlas.get("source") != source:
            raise SystemExit(f"FAIL: {pack.name} atlas is stale; run petpack.py build")
        if pack.name == "mimo":
            design = ROOT / "docs/eshell-pets-redesign-2026-10-23/design/mimo.pet.json"
            assert (pack / "pet.json").read_bytes() == design.read_bytes(), "Mimo design/runtime diverged"
            source_data = json.loads((pack / "pet.json").read_text())
            assert source_data["animations"]["code"]["settleAfterLoops"] == 4
            assert source_data["animations"]["hop"] == {
                "frames": ["hop_0", "hop_1", "hop_2"], "ms": [80, 100, 90], "loop": False}
            assert source_data["animations"]["doze"]["ms"] == [600, 600, 700]
            assert source_data["animations"]["wake"]["ms"] == [120, 260, 220, 180]
            assert sum(source_data["animations"]["love"]["ms"]) == 700
            heart_rows = [min(y for y, row in enumerate(source_data["frames"][f"love_{i}"])
                              if "c" in row[16:]) for i in range(3)]
            assert heart_rows == [5, 2, 0], "the heart must rise five cells within the canvas"
            assert all("c" not in row[16:] for row in source_data["frames"]["happy_0"]), "heart must not reappear"
        print(f"PASS package {pack.name}")


def run_fixture(name, platform, timeout):
    with tempfile.TemporaryDirectory(prefix="isla-pets-") as tmp:
        config = Path(tmp) / "config.json"
        config.write_text("{}\n")
        env = dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM=platform)
        result = subprocess.run(["quickshell", "-p", str(ROOT / "bar" / name)], env=env,
                                capture_output=True, text=True, timeout=timeout)
    output = result.stdout + result.stderr
    passed = [line for line in output.splitlines() if "PASS:" in line]
    noise = [line for line in output.splitlines()
             if ("pets/" in line or "TypeError" in line or "ReferenceError" in line) and "UserAvatar" not in line]
    if result.returncode != 0 or not passed or noise:
        raise SystemExit(f"FAIL: {name} ({result.returncode})\n" + "\n".join(output.splitlines()[-30:]))
    print(f"PASS {name}: {passed[-1].split('PASS:', 1)[1].strip()}")


def main():
    subprocess.run(["node", str(ROOT / "bar/tests/pet-events.cjs")], check=True)
    check_packs()
    overlay = (ROOT / "bar/windows/IslandOverlay.qml").read_text()
    assert "pillLook(point.position.x, point.position.y, pill, hovered)" in overlay, "hover must use the event position"
    run_fixture("pets-regression.qml", "offscreen", 90)
    run_fixture("pets-rail-regression.qml", "offscreen", 90)
    run_fixture("pets-media-gather-regression.qml", "offscreen", 30)
    run_fixture("pets-media-perch-regression.qml", "offscreen", 30)
    if os.environ.get("WAYLAND_DISPLAY"):
        run_fixture("pets-overlay-regression.qml", "wayland", 120)
    else:
        print("SKIP pets-overlay-regression.qml: needs Wayland")


if __name__ == "__main__":
    main()
