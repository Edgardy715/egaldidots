# Cached SVG experiment · 2026-10-22

The cached SVG body did **not** demonstrate a memory improvement. Warm PSS
increased in idle, reacting, and sleeping in this bounded comparison. Reaction
CPU also increased; sleeping CPU decreased. This experiment therefore does not
support selecting SVG on performance grounds.

The exact initial benchmark was repeated without changes: production PetHost
36×36 in the same 160×100 Wayland fixture, private `{}` config, 1 s startup
excluded, 3.5 s measured, two rounds in opposite order. The run began after a
30 s pause requested by the coordinator to avoid concurrent visual QA. Runtime,
fixture, companion and runner hashes remained stable throughout. Fixture and
runner hashes match the initial run. The production change replaced the static
Shape path with a theme-colored cached SVG Image, retaining the same transform.

| Scenario | Initial CPU % core | Cached CPU % core | Initial PSS KiB | Cached PSS KiB | Cached PSS delta vs own disabled |
| --- | ---: | ---: | ---: | ---: | ---: |
| disabled | 0 | 0 | 111338 | 108880 | baseline |
| idle | 0 | 0 | 119256 | 124083 | +14.85 MiB |
| reacting | 8.425 | 9.994 | 121117 | 125010.5 | +15.75 MiB |
| hidden | 0 | 0 | 109009 | 110962 | +2.03 MiB |
| sleeping, actively breathing | 9.275 | 8.425 | 124563.5 | 125402.5 | +16.14 MiB |

Absolute PSS change vs the initial implementation: idle +4827 KiB, reacting
+3893.5 KiB, sleeping +839 KiB. Disabled baseline decreased 2458 KiB between
batches, so comparing incremental cost against each batch's own disabled
baseline produces an even larger increase. Independent-process PSS/shared-page
accounting and short samples limit attribution; this is evidence of no observed
improvement, not a precise causal estimate of the SVG decoder's memory cost.

The original thresholds were retained: quiet/hidden CPU increment ≤0.5 points,
animated CPU ≤10% of one core, warm PSS increment ≤8 MiB and driver p95 ≤25 ms.
CPU passes within this run, but reacting at 9.994% leaves almost no margin.
PSS exceeds budget in all three loaded scenarios. Driver p95 remains 5 ms in
both animated scenarios and is a QML driver measurement, not physical FPS.
One process was observed throughout. Disabled/hidden loaders were unloaded;
both sleeping runs confirmed asleep, breathing=false and breath=0 at 8.2 s.

`results.json` contains source hashes, environment, samples, intervals and both
rounds; `comparison.json` contains exact numeric before/after deltas. `sources/`
preserves the measured immediate sources. Original logs are in `round*.log`.
The unchanged runner self-test and Python compile evidence are retained at
`../performance/validation.json`; they were not rerun. Actual Wayland execution
and all runtime state assertions passed again.

No additional tuning, threshold adjustment or extra rounds were used. No full
shell, GPU-memory, energy, physical FPS or settled-sleep CPU/PSS claim follows
from this test. Visual QA belongs to the coordinator's separate evidence.
