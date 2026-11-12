# Wallpaper scan measurement · 2026-10-21

## Result

No production change is justified for the current library of 35 wallpapers.
The slowest measured scan of the real directory with a valid warm cache took
5 ms through `scanDone`, including the synchronous signal handler. The UI event
loop gap was also 5 ms. A cold-cache scan peaked at 1 ms. This is below one
60 Hz frame interval (16.7 ms); the warm peak is just above a 240 Hz interval
(4.2 ms). The offscreen fixture measured event-loop blocking, not displayed
frames or presentation latency.

At larger counts, the synchronous path scales past a frame: a warm 1,000-image
fixture peaked at 85 ms, and 10,000 images at 851 ms. If real libraries grow
into that range, move directory enumeration, sorting and cache validation into
one QtConcurrent worker. Keep only the latest pending scan when refreshes arrive
while it runs; publish `scanDone` and `scanFinished` for the latest serial, and
discard stale work. `startScan` currently emits `scanDone` synchronously, so
callers must continue to consume the same result signals without relying on a
blocking return value. Python or Rust would add a process/FFI boundary around
Qt's existing image/cache APIs without reducing their dominant filesystem work.

## Measurements

The scan and call measurements use QML `Date.now()` (millisecond resolution).
Each `scanDone` callback occurs inside the `startScan` call. The 1 ms heartbeat
records the largest event-loop gap around each individual scan; timing includes
normal timer jitter. Runs were serial, with 24 scans for 35 images, 10 for
1,000, and 3 for 10,000.

The scanner object is created and called from QML, so `startScan` runs on that
object's QML thread. In contrast, thumbnail decode/resize/write already runs in
`QtConcurrent::run` from `WallpaperScanner::generateThumb`; thumbnail work is
outside these scan timings.

| Dataset | Cache | Files | `scanDone` median / max | Call max | Event-loop gap max |
| --- | --- | ---: | ---: | ---: | ---: |
| Real `/home/zdito/Wallpapers` | cold | 35 | 0 / 1 ms | 1 ms | 2 ms |
| Real `/home/zdito/Wallpapers` | warm | 35 | 3 / 5 ms | 5 ms | 5 ms |
| Fixture | cold | 35 | 0.5 / 1 ms | 1 ms | 2 ms |
| Fixture | warm | 35 | 3 / 4 ms | 4 ms | 4 ms |
| Fixture | cold | 1,000 | 14 / 15 ms | 16 ms | 16 ms |
| Fixture | warm | 1,000 | 82 / 84 ms | 85 ms | 85 ms |
| Fixture | cold | 10,000 | 155 / 160 ms | 162 ms | 162 ms |
| Fixture | warm | 10,000 | 844 / 849 ms | 851 ms | 855 ms |

```json
{
  "real_35_cold": {"iterations": 24, "scanDoneMedianMs": 0, "scanDoneMaxMs": 1, "callMaxMs": 1, "eventLoopGapMaxMs": 2},
  "real_35_warm": {"iterations": 24, "scanDoneMedianMs": 3, "scanDoneMaxMs": 5, "callMaxMs": 5, "eventLoopGapMaxMs": 5},
  "fixture_35_cold": {"iterations": 24, "scanDoneMedianMs": 0.5, "scanDoneMaxMs": 1, "callMaxMs": 1, "eventLoopGapMaxMs": 2},
  "fixture_35_warm": {"iterations": 24, "scanDoneMedianMs": 3, "scanDoneMaxMs": 4, "callMaxMs": 4, "eventLoopGapMaxMs": 4},
  "fixture_1000_cold": {"iterations": 10, "scanDoneMedianMs": 14, "scanDoneMaxMs": 15, "callMaxMs": 16, "eventLoopGapMaxMs": 16},
  "fixture_1000_warm": {"iterations": 10, "scanDoneMedianMs": 82, "scanDoneMaxMs": 84, "callMaxMs": 85, "eventLoopGapMaxMs": 85},
  "fixture_10000_cold": {"iterations": 3, "scanDoneMedianMs": 155, "scanDoneMaxMs": 160, "callMaxMs": 162, "eventLoopGapMaxMs": 162},
  "fixture_10000_warm": {"iterations": 3, "scanDoneMedianMs": 844, "scanDoneMaxMs": 849, "callMaxMs": 851, "eventLoopGapMaxMs": 855}
}
```

## Method and reproduction

`bar/tests/wallpaper-scan-benchmark.py` builds the current `Wpscan` source as a
Release module in a temporary directory and drives
`bar/tests/wallpaper-scan-benchmark.qml`. It reads the real wallpaper directory
without modifying it and gives every run a temporary cache. Synthetic fixtures
use 2×2 PNG hardlinks. Warm-cache metadata and 320×180 JPEG thumbnails are
created in that temporary cache, matching the scanner's cache signature and
header checks. The cold case has an empty cache. The measured plugin and all
fixtures are removed after the command exits; summary measurements are also
available as JSON at the `--output` destination.

```sh
python3 bar/tests/wallpaper-scan-benchmark.py \
  --output /tmp/isla-wallpaper-scan-benchmark-20261021.json
```

The scanner source was unchanged during the measurement; its SHA-256 was
`370561101b62facf502bfa73f4fbf4c3678bb0091127b7e9873cba347e65e018`.
The measurement reports no CPU percentage, power draw, or frame presentation
rate. `scanDone` is synchronous in the current C++ implementation, and the
measured callback latency tracks the full `startScan` work. No wallpaper was
applied and no personal cache was written.
