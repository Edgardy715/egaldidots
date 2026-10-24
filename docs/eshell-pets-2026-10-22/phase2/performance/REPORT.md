# Pets phase 2 performance · 2026-10-22

Measured production `PetHost` at 36×36 logical pixels, centered inside the same
160×100 Wayland window in every scenario. The fixture has no audio integration,
workspace changes, media changes, or personal configuration writes. `ISLA_CONFIG`
is a private temporary `{}` profile. The live compositor remained running.

`python bar/tests/pets-performance.py` launches one process per sample, excludes
1 second of startup, then samples CPU/PSS for 3.5 seconds. Round 1 is disabled,
idle, reacting, hidden, sleeping; round 2 reverses that order. Reacting triggers
the production reaction every 650 ms. Sleeping starts the native finite breath
sequence at the measurement boundary, so these data describe active breathing.
Both sleeping runs additionally confirm asleep, `breathing=false`, `breath=0`
at 8.2 seconds; that extra wait is excluded from CPU/PSS results.

## Results

CPU is percentage of one core; PSS is the median of each run's process-tree
samples and then the median across the two runs. Process count was exactly 1
throughout all measured scenarios. No process helpers appeared.

| Scenario | CPU % core | PSS KiB | PSS delta vs disabled | Animation driver p95 |
| --- | ---: | ---: | ---: | ---: |
| disabled | 0.000 | 111338 | baseline | inactive |
| idle | 0.000 | 119256 | +7.73 MiB | inactive |
| reacting | 8.425 | 121117 | +9.55 MiB | 5 ms both runs |
| hidden | 0.000 | 109009 | −2.27 MiB | inactive |
| sleeping, actively breathing | 9.275 | 124563.5 | +12.92 MiB | 5 ms both runs |

The declared CPU budget passes: quiet/hidden add ≤0.5 percentage points and
animated samples remain ≤10% one core. The second sleeping run was close to the
limit at 9.995%, so this does not establish substantial CPU headroom. PSS ≤8 MiB
increment passes idle but **exceeds budget for reacting and sleeping**. No
thresholds were changed and no extra samples were added to seek a pass.

The driver is a `FrameAnimation` enabled only while the runtime reports reacting
or breathing. Maximum measured interval was 6 ms during reactions and 8 ms while
breathing. This passes the fixture's 25 ms driver-p95 guide. These are QML driver
intervals recorded with `Date.now()` millisecond resolution, including occasional
0 ms duplicate timestamps; they are not physical display FPS or compositor frame
presentation measurements. The monitor reports 239.964 Hz, scale 1, 1920×1080.

## Validation and evidence

- `results.json`: all samples, both rounds, durations, runtime state, CPU/PSS,
  frame intervals, environment, compositor version/monitor data, and source hashes.
- `round*.log`: original Quickshell output, including Loader unload assertions
  for disabled/hidden and finite breathing completion for both sleeping runs.
- `validation.json`: parser/percentile/aggregation/live-proc self-test PASS,
  Python compile PASS, Qt version, and supporting singleton source hashes.
- The runner checks its fixture/runtime/companion source hashes remained unchanged
  across the complete measurement; the run passed this check.

## Limits

This is an isolated, warm PetHost comparison, not a before/after measurement of
the full shell, startup, GPU memory, energy use, physical FPS, or long-run behavior.
PSS includes Qt, loaded singletons and driver mappings; independently started
processes and shared-page accounting can vary. Hidden's lower PSS than disabled
illustrates that these short process measurements have an attribution floor.
CPU uses Linux scheduler tick counters: zero means no observed tick in the
window, not proof that execution consumes literally no CPU. Instrumentation
itself adds some work during animation. Active sleeping PSS includes transient
animation allocations; settled sleeping CPU/PSS were not separately measured.
Compositor visual captures and animation QA belong to the coordinator's separate
evidence; none were duplicated by this benchmark.
