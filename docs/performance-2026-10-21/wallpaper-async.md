# Wallpaper scanner async · 2026-10-21

Directory enumeration, sorting, cache directory creation and thumbnail metadata/header
validation now run in the existing QtConcurrent pool. The QObject only starts the
job and publishes its result. Each instance has one scan worker; new requests
replace the last pending request. A stale completion starts that latest request
without publishing either completion signal. Request values are copied into the
worker; it never captures the QObject.

`scanDone` keeps the same JSON array and `scanFinished` keeps the same arguments.
Completion is now asynchronous. `m_doneSerial` is updated before publication, so
`isScanning()` is false in the current `scanDone` handler. If that handler starts
another scan, the old `scanFinished` is suppressed. Deletion during a worker or
inside `scanDone` is safe. Thumbnail generation/invalidation code is unchanged.
The production singleton already consumes the signals without relying on a
synchronous return. Its JSON-to-JS conversion and list construction still run on
the UI thread.

## Measurement

The baseline JSON was copied before repeating the benchmark; it is preserved in
`wallpaper-before.json`. Current output is `wallpaper-after.json`. Both runs were
serial, offscreen, with the same real library and synthetic fixture sizes. The
QML benchmark now advances after `scanDone` so it handles both synchronous and
asynchronous implementations. Call latency is measured independently. Timings
use millisecond-resolution `Date.now()`; 0 ms means below that resolution.

| Dataset | Cache | Call max before → after (ms) | Heartbeat gap max before → after (ms) | scanDone max before → after (ms) |
| --- | --- | ---: | ---: | ---: |
| wallpapers-real | cold | 1 → 0 | 2 → 2 | 1 → 1 |
| wallpapers-real | warm | 5 → 1 | 5 → 2 | 5 → 3 |
| fixture-35 | cold | 1 → 1 | 2 → 2 | 1 → 1 |
| fixture-35 | warm | 4 → 1 | 4 → 2 | 4 → 3 |
| fixture-1000 | cold | 16 → 1 | 16 → 4 | 15 → 14 |
| fixture-1000 | warm | 85 → 1 | 85 → 5 | 84 → 90 |
| fixture-10000 | cold | 162 → 0 | 162 → 32 | 160 → 165 |
| fixture-10000 | warm | 851 → 0 | 855 → 30 | 849 → 871 |

The 10,000-image warm call returns below 1 ms instead of blocking for 851 ms;
its measured maximum heartbeat gap falls from 855 to 30 ms. The worker still
performs the same filesystem checks, and completion still transfers the full
array to QML. This does not establish frame presentation/FPS or eliminate all
main-thread work. No CPU utilization or power measurement was taken. The real
35-image warm case changes call max from 5 to 1 ms and heartbeat gap from 5 to
2 ms; async overhead was not justified by that small dataset alone.

## Checks and reproduction

```sh
python bar/tests/wallpaper-scanner-async.py --build /tmp/isla-wpscan-async-tested-20261021
ISLA_WPSCAN_BUILD=/tmp/isla-wpscan-async-tested-20261021 python bar/tests/wallpaper-scanner.py
python bar/tests/wallpaper-scan-benchmark.py --build /tmp/isla-wpscan-async-tested-20261021 --output /tmp/wallpaper-after.json
```

- Native Release build and assert-based C++ lifecycle regression: PASS. The
  test holds the pool to check A→B→C coalescing, stale suppression, one watcher
  while active, no B cache creation, `isScanning()` transitions, reentry from
  `scanDone`, deletion with queued work, deletion while a metadata FIFO holds
  the worker running, and deletion directly inside `scanDone`.
- Existing scanner regression: PASS for cold cache, valid cache reuse, changed
  source invalidation and corrupt thumbnail regeneration (six QML invocations).
- Benchmark: PASS, all counts and callback totals checked for all eight cases.
- `git diff --check` for production scanner sources: PASS.

Builds stayed in `/tmp`; no module was installed, no running shell was restarted,
and no wallpaper or personal thumbnail cache was changed. The test uses Linux
FIFOs to deterministically hold the metadata read; its scope matches this shell.
Already-running stale jobs are allowed to finish; pending jobs are coalesced.
The QtConcurrent pool is shared with thumbnail jobs, so scan completion can wait
behind other pool work. This change preserves that existing dependency.

Current production C++ SHA-256: `19e537fd3e1b14f6164cb4a0a0307cf6de066dea41291a556865b5eaf5300c30`.
