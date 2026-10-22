"""Measure WallpaperScanner.startScan without touching the user's cache."""

import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "bar/tests/wallpaper-scan-benchmark.qml"
REAL_WALLPAPERS = Path.home() / "Wallpapers"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif", ".bmp"}


def scanner_hash(path):
    value = 5381
    for byte in str(path).encode():
        value = ((value << 5) - value + byte) & 0xFFFFFFFF
    return f"{value:x}"


def warm_cache(source_dir, cache_dir):
    cache_dir.mkdir(parents=True, exist_ok=True)
    image = cache_dir / "benchmark-thumb.jpg"
    Image.new("RGB", (320, 180), "#334455").save(image, quality=78)
    hashes = set()
    for source in sorted(path for path in source_dir.iterdir()
                         if path.is_file() and path.suffix.lower() in EXTENSIONS):
        key = scanner_hash(source)
        assert key not in hashes, f"scanner hash collision: {source}"
        hashes.add(key)
        target = cache_dir / f"{key}.jpg"
        target.hardlink_to(image)
        source_stat, target_stat = source.stat(), target.stat()
        metadata = {"source": str(source), "sourceSize": source_stat.st_size,
                    "sourceModified": source_stat.st_mtime_ns // 1_000_000,
                    "cacheSize": target_stat.st_size,
                    "cacheModified": target_stat.st_mtime_ns // 1_000_000,
                    "width": 320, "height": 180, "quality": 78}
        target.with_name(target.name + ".meta.json").write_text(
            json.dumps(metadata, separators=(",", ":")))
    image.unlink()


def run_qml(source_dir, cache_dir, iterations, plugin):
    expected = sum(path.is_file() and path.suffix.lower() in EXTENSIONS
                   for path in source_dir.iterdir())
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QML_IMPORT_PATH=str(plugin),
               ISLA_SCAN_DIR=str(source_dir), ISLA_SCAN_CACHE=str(cache_dir),
               ISLA_SCAN_ITERATIONS=str(iterations), ISLA_SCAN_EXPECTED=str(expected))
    result = subprocess.run(["quickshell", "-p", str(FIXTURE)], env=env,
                            capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    marker = "WALLPAPER_SCAN_RESULT "
    records = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
    assert result.returncode == 0 and len(records) == 1, output
    measurement = json.loads(records[0])
    assert measurement["items"] == expected, output
    assert measurement["callbacks"] == iterations, output
    measurement["scanDoneMs"] = summarize(measurement.pop("scanDoneSamplesMs"))
    call_samples = measurement.pop("startScanCallSamplesMs")
    measurement["startScanCallMs"] = summarize(call_samples)
    measurement["sumStartScanCallMs"] = sum(call_samples)
    return measurement


def summarize(values):
    return {"median_ms": statistics.median(values), "max_ms": max(values)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/isla-wallpaper-scan-benchmark.json"))
    parser.add_argument("--build", type=Path, help="reuse a built Wpscan module instead of building in a temp directory")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="isla-wallpaper-scan-") as directory:
        temp = Path(directory)
        plugin = args.build
        if plugin is None:
            plugin = temp / "build"
            subprocess.run(["cmake", "-S", str(ROOT / "wpscan"), "-B", str(plugin),
                            "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release"], check=True,
                           capture_output=True, text=True)
            subprocess.run(["cmake", "--build", str(plugin), "--parallel", "2"], check=True,
                           capture_output=True, text=True)

        small_png = temp / "fixture.png"
        Image.new("RGB", (2, 2), "#123456").save(small_png)
        datasets = [("wallpapers-real", REAL_WALLPAPERS, 35, 24)]
        for count, iterations in ((35, 24), (1000, 10), (10000, 3)):
            source_dir = temp / f"fixture-{count}"
            source_dir.mkdir()
            for index in range(count):
                (source_dir / f"wallpaper-{index:05d}.png").hardlink_to(small_png)
            datasets.append((f"fixture-{count}", source_dir, count, iterations))

        measurements = []
        for name, source_dir, count, iterations in datasets:
            for cache_state in ("cold", "warm"):
                cache_dir = temp / f"cache-{name}-{cache_state}"
                cache_dir.mkdir()
                if cache_state == "warm":
                    warm_cache(source_dir, cache_dir)
                sample = run_qml(source_dir, cache_dir, iterations, plugin)
                measurements.append({"dataset": name, "cache": cache_state,
                                     "files": count, "iterations": iterations,
                                     **sample})

        result = {"scanner": str(ROOT / "wpscan/WallpaperScanner.cpp"),
                  "plugin_build": str(plugin), "real_wallpapers": str(REAL_WALLPAPERS),
                  "measurements": measurements}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        for item in measurements:
            print(f"{item['dataset']:18} {item['cache']:4} files={item['files']:5} "
                  f"scan med/max={item['scanDoneMs']['median_ms']:.1f}/"
                  f"{item['scanDoneMs']['max_ms']:.1f} ms "
                  f"call max={item['startScanCallMs']['max_ms']:.1f} ms "
                  f"max single-scan heartbeat-gap="
                  f"{item['maxHeartbeatGapMs']:.1f} ms")
        print(f"JSON: {args.output}")


if __name__ == "__main__":
    main()
