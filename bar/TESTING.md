# Tests

Run commands from the repository root. Python tests that write configuration
use temporary directories; do not point test fixtures at your personal settings.

## Configuration and data

`python bar/tests/launcher-media-clearance.py` (Wayland) closes the launcher
with an isolated MPRIS fixture playing, on the production IslandOverlay, for long
and short visits and under reduced motion. Per frame it asserts that the
unjoined media droplet never overlaps the returning pill and that the pill never
widens after the droplet buds (not even from a launcher-width blip at the
handoff). QtTest failures are not printed under `qs -p`: the runner requires the
final PASS marker.

Settings integration verifies defaults, the removed `pet` workspace style falling back
to the default, temporary persistence/discard and the real editor.

```sh
sh bar/tests/verify-config.sh
node bar/tests/media-source.cjs
node bar/tests/lyrics.cjs
python bar/tests/settings-integration.py
python bar/tests/hyprland-settings.py
python3 bar/scripts/test-hypr-plugins.py
python3 bar/scripts/test-hypr-binds.py
python bar/tests/nmcli-service.py
python bar/tests/brightness-service.py
python starship/.config/starship/test_matugen.py
```

The configuration gate includes settings validation, component boundaries and
the calculator parser. The integration test runs the QML settings service and
checks IPC, reloads, conflicts and atomic saves.

## Performance and process lifetime

`python bar/tests/settings-navigation-performance.py --rounds 2 --output
/tmp/settings-navigation.json` (one line) alternates isolated Wayland copies of
the current and frozen baseline Edots navigation. It records driver intervals
and private Config call counters; these are not physical display FPS. The
`--baseline-lazy-check` mode verifies that the old row creates hidden editors.
Run controls/UX Wayland fixtures serially to avoid focus interference.

```sh
python bar/tests/sample-process.py --self-test
python bar/tests/session-soak.py --self-test
python bar/tests/cava-stream.py
python bar/tests/cava-envelope.py
python bar/tests/cava-backend.py
ISLA_CAVA_RUST_BINARY="$HOME/.local/share/isla/bin/isla-cava-stream" python bar/tests/cava-rust-lifecycle.py
python bar/tests/nmcli-lifetime.py
python bar/tests/audio-lifetime.py
QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py --output /tmp/isla-qml-performance
python bar/tests/wallpaper-scanner-async.py --build /tmp/isla-wpscan-test
ISLA_WPSCAN_BUILD=/tmp/isla-wpscan-test python bar/tests/wallpaper-scanner.py
```

`rolling-elastic-regression.qml` covers RollingNumber (direction follows the value,
queued rolls burst, `immediate` is 1:1, reduced motion is static) and the rubber band
of `Slider` and `AudioFader` (value clamps, stretch is bounded, spring returns).

The Cava envelope and discovery tests use synthetic data and fake producers;
they never capture personal audio. `nmcli-lifetime.py` checks graceful quit,
SIGTERM, hot reload and monitor restart using fake NetworkManager commands.
`desktop-status-audio-rebind-regression.qml` tests observer replacement with
mock devices. `desktop-status-capslock-regression.qml` drives Caps Lock
from fake sysfs LEDs (discovery, OR across keyboards, removal, hyprctl fallback). The native scanner test checks stale scans, coalescing, reentry
and destruction while work is active.

`wallpaper-scan-benchmark.py --build /tmp/isla-wpscan-test` measures call latency,
completion and a QML heartbeat with temporary caches. `sample-process.py --pid
PID --seconds 30 --output /tmp/process.json` reads Linux CPU/RSS/PSS plus
Pss_Anon/Pss_File/Swap/SwapPss (zram swaps cold pages out, so PSS alone falls).
`session-soak.py` also logs `pss_with_swap_kib` and live descendants
(`live_children*`, `tree_cpu_percent`): `child_cpu_ticks` only sees reaped children. For a real
audio-server discovery comparison, `cava-discovery-performance.py --before
/path/to/baseline/cava_stream.py --output /tmp/cava.json` uses an unresolved test
identity and performs read-only queries. Animation-driver/heartbeat intervals
are not display FPS. See `docs/performance-2026-10-21/REPORT.md` for evidence and
the exact baseline source archive.

The hybrid backend's QML caller, exec ownership, fallback and atomic install
are checked by `cava-backend.py` using fake producers. Rust unit tests and clippy
run in `rust/cava-stream` with `cargo test --locked` and
`cargo clippy --locked --all-targets -- -D warnings`. Run the same discovery and
capture regression against the installed helper with `ISLA_CAVA_TEST_BINARY=
/absolute/path/to/isla-cava-stream python bar/tests/cava-stream.py` (one line).
`cava-rust-lifecycle.py` tests forced death, blocked snapshots and stdout using
fake processes. `cava-hybrid-performance.py --rust /absolute/path/to/helper
--seconds 12 --rounds 2 --output /tmp/cava-hybrid.json` compares Python/Rust with
real CAVA and a private inaudible null sink, then removes its stream/module and
checks unchanged defaults. It excludes the shared audio server and tone producer
from process-tree CPU/PSS. See `docs/rust-cava-2026-10-21/REPORT.md`.

The optional peak reducer keeps the Python bridge and its envelope. Build with
`sh scripts/build-audio-peak.sh`. Run `cargo test --locked` and
`cargo clippy --locked --all-targets -- -D warnings` in `rust/audio-peak`.
`python bar/tests/audio-peak.py --library /absolute/path/libisla_audio_peak.so`
checks exact baseline/native/fallback parity including fragmented PCM and
non-finite values. `python bar/tests/audio-peak-install.py` checks atomic install
and preservation after build/copy failures using a fake compiler.
`python bar/tests/audio-peak-qml.py --library /absolute/path/libisla_audio_peak.so`
checks the real QML controller with a private silent monitor, both native and
fallback, including close/reopen and child cleanup. This is offscreen integration,
not visual QA. `audio-lifetime.py` uses fake audio commands to test stdin EOF,
TERM/KILL, a blocked query and subscription EOF, without accessing host audio.
`python bar/tests/audio-peak-performance.py --library /absolute/path/libisla_audio_peak.so
--seconds 12 --rounds 4 --output /tmp/audio-peak.json` (one line) measures complete
feed calls and the real bridge with two private, inaudible meters. It verifies
the loaded library, attack/release, EOF/TERM child cleanup and unchanged defaults.
CPU/PSS excludes the shared server and tone producer; this is not a whole-shell
benchmark. See `docs/rust-audio-peak-2026-10-21/REPORT.md`.

## Installer and authentication

The saved clipboard reader can be built with `sh scripts/build-clipboard-list.sh`.
`python bar/tests/clipboard-list.py --binary /absolute/path/isla-clipboard-list`
checks metadata parity, private permissions, Python flock compatibility,
cancelled reads, BrokenPipe and JSON compatibility via exec fallback.
`python bar/tests/clipboard-list-backend.py` checks launcher exec/argv and atomic
build/copy failures using fake binaries. Run `bash bar/tests/clipboard-library-regression.sh`
with the native binary installed to cover the full QML controller with fake
cliphist/wl-copy and a temporary library. It must also pass when the binary is
absent. `python bar/tests/clipboard-list-performance.py --binary /absolute/path/isla-clipboard-list
--output /tmp/clipboard-list.json` (one line) alternates CLI and QML read requests
over private 0/100/1000-entry libraries, with separate sampled memory runs.
QML times measure data readiness, not presentation or screen FPS.

```sh
python scripts/test-install.py
python bar/tests/nvidia-launcher.py
lua bar/tests/workspace-motion.lua
python scripts/test-scrolloverview-loader.py
python bar/tests/lockscreen-launcher.py
python bar/tests/auth-backend.py
python bar/tests/auth-bridge.py
python bar/tests/auth-transport.py
python bar/tests/session-logout.py
bash bar/tests/clipboard-regression.sh
python bar/tests/clipboard-library.py
bash bar/tests/clipboard-library-regression.sh
bash bar/tests/clipboard-workflow-regression.sh
```

Recovery tests require Python, GNU Stow and ripgrep. They use temporary homes,
real Stow, and simulated package managers and desktop commands. Authentication
tests use isolated agents, sockets and processes.

## QML fixtures

`bar/*-regression.qml` contains focused checks for layout, routing, input and
motion. Run an individual fixture with a temporary configuration:

```sh
ISLA_CONFIG=/tmp/isla-motion-test.json QT_QPA_PLATFORM=offscreen \
  quickshell -p bar/motion-regression.qml
```

`bar/companion-continuity-regression.qml` checks spring trajectory across
30/60/144/240 Hz, delayed frames, capture/reopen, geometric neck pinching,
continuous return edges and switching reduced motion during a transition.

Pill motion edge cases (offscreen unless noted):
`content-hold-regression.qml` keeps content while the same surface resizes;
`surface-swap-close-regression.qml` closes during a pending swap without the
previous surface reappearing; `notification-breath-regression.qml` checks the
continuous breath and that the reading hold is unscaled;
`fullscreen-hide-regression.qml` (Wayland) checks that the pill and drops share
one fullscreen withdrawal and that reduced motion resolves it directly.

`bar/settings-navigation-regression.qml` checks atomic page selection, hidden
composition rows, font editors only on font fields, resize, search, drafts,
rapid retargeting and reduced motion. Run on Wayland with a temporary ISLA_CONFIG.
Its FrameAnimation intervals are driver samples, not display FPS; measure alone.

`bar/settings-async-regression.qml` checks cold asynchronous editor loading,
cancel/reopen while loading, retention and reduced motion on Wayland.

`bar/lockscreen-performance-regression.qml` runs twelve opening/closing
transitions in a regular preview window and checks that each settles. With
`ISLA_LOCK_WALLPAPER` set to a local wallpaper it reports animation-driver frame
intervals; these are not display presentation FPS. Use a temporary `ISLA_CONFIG`
and Wayland. The fixture never acquires the session lock or authenticates.

`bar/lockscreen-filmstrip.qml` is visual QA for the whole lock choreography
(secure → rest → access → typing → error → retype → success → return to the
desktop). Its verify steps call `attemptUnlock()`, so they show the liquid beads
gathering into the submit drop, the drain on error and the swell on success. It saves half-size frames every `ISLA_LOCK_FRAME_MS` (40 ms) to
`ISLA_LOCK_CAPTURE_DIR` and logs when `exitFinished` fires. Pass a desktop
capture as `ISLA_LOCK_SNAPSHOT` (for example `grim -t ppm /tmp/desk.ppm`) to see
the snapshot blur and the return to the desktop; `ISLA_LOCK_WIDE=1` opens it
fullscreen. It never acquires the lock or starts PAM. Frames come from the scene
graph, so judge continuity, not FPS. The same snapshot works in the regular
preview: `QS_LOCK_PREVIEW=1 QS_LOCK_PREVIEW_SNAPSHOT=/tmp/desk.ppm quickshell -p bar/lockscreen.qml`.

Use Wayland for fixtures involving layer surfaces, focus or native keyboard
input. Some fixtures need a driver script or simulated service; check their
setup before running them directly.

```sh
python bar/tests/settings-surface-switch.py
python bar/tests/settings-media-routing.py
python bar/tests/settings-ux.py
python bar/tests/hyprland-settings-ui.py
python bar/tests/shortcut-explorer-ui.py
python bar/tests/overlay-native-input.py
python bar/tests/desktop-integration.py
```

These tests need a running Wayland session. Offscreen checks do not establish
visual quality or compositor input behavior.

`desktop-integration.py` uses a disposable application and temporary configuration,
data/state and askpass socket. It checks actual typing after Escape on 14 panels,
nested settings search, workspace confirmation, actual compositor fullscreen and
DesktopEntry launch/focus with both normal and reduced motion. Run it alone:
other native fixtures can capture its keyboard. It restores the previous active
window and never authenticates or changes the user's workspaces or wallpaper.

## Service and interaction regressions

`nmcli-service.py` runs a fake nmcli: refresh bursts serialize, callbacks survive
failures/reentry, and completed command objects are destroyed. `brightness-service.py`
uses fake sysfs commands only: slider bursts, accumulated steps, fallback denial
and stale reads never change hardware or invoke polkit.

`launcher-pending-regression.qml` checks pending-result activation, hidden searches
and reopening. `clipboard-preview-jobs-regression.qml` checks simultaneous preview
completion and cache retention; the library regression also checks long unsaved
history text after library refresh. `breathe-border-regression.qml` checks hidden
and reduced-motion animation gates, including agile speed. Use temporary ISLA_CONFIG.

`QT_QPA_PLATFORM=wayland python bar/tests/wallpaper-source.py` loads a filename
with spaces, #, ?, percent and Unicode in overview and lockscreen preview windows.
It uses a temporary config/cache, applies no wallpaper and acquires no session lock.
Optional ISLA_TEST_OUTPUT saves mock-only screenshots.

## Manual checks

Direct recording: `python bar/tests/gpu-recording.py` uses fake recorder
executables and temporary output; never captures the desktop. It checks owned
process start, pause, stop/finalization, invalid input, errors and EOF cleanup.
`recording-view-regression.qml` checks audio toggles, native controls and
morph/hidden/reduced. `recording-integration-regression.qml` tests tabs, countdown
cancellation on tab, route and close, pill recording/pause/unknown and saved
feedback with injected snapshots and observation disabled. Use temporary
`ISLA_CONFIG`; optional `ISLA_TEST_OUTPUT` captures mock-only states.
`recording-drop-regression.qml` runs on Wayland with injected states and no
backend. It checks the left droplet, music on the right, click routing, normal
and reduced absorption/interruption, split/compact center alignment, fullscreen,
session/settings and narrow-space fallback. `overlay-input-policy-regression.qml`
checks reflected recording bounds without grabbing desktop-wide idle input.
Real capture additionally needs the ScreenCast picker and a working GPU encoder.

`surface-materialize-regression.qml` covers the surface spring and materialization: open
overshoot 2.5-4 % and settling, resize <= 0.5 %, close <= 1.2 %, retarget with position and
velocity equality, notification and workspace paths unchanged, reduced motion direct, and the
host's scale/blur layer (retired at p=1, A to B at 0.97, blur limit on large surfaces).
`PillMorphMotion.manualStep` drives `step(dt)` deterministically. Run with a temporary
`ISLA_CONFIG`: `QT_QPA_PLATFORM=offscreen quickshell -p bar/surface-materialize-regression.qml`.
Visual capture: `docs/surface-materialize-2026-10-25/capture.py <before|after> <dir>` (Wayland,
grim) and `sheets.py`.
`focus-session-regression.qml` checks deadlines, suspend, pause/resume milliseconds,
single completion, choosing the next duration, custom minutes and keyboard input.
`notification-attention-regression.qml` and `notification-priority-regression.qml`
check informational deferral, critical/auth priority, expiry and consuming the
displayed notification by identity. Give notification fixtures a temporary
`XDG_STATE_HOME` as well as `ISLA_CONFIG` to isolate their queue storage.

- Open and close each panel; Escape and clicking outside should return to rest.
- Switch panels during a transition and check that the latest request wins.
- Toggle split/compact layouts and modules, including reduced motion.
- Check keyboard focus, Tab navigation, disabled controls and large text.
- Play, pause and change tracks; check metadata, timeline and lyrics.
- Save settings, restart Isla and check that the saved values return.
- Check both connected monitors when available.

Test real locking, PAM, Wi-Fi and power actions separately. Simulated tests do
not verify those operations on your hardware.

`bar/lockscreen-power-regression.qml` runs the energy popup in a regular Wayland
preview window. It checks entrance, interrupted close/reopen, focus restoration,
confirmation, large text and reduced motion. Power actions emit fixture signals
only. Run with a temporary `ISLA_CONFIG`; `ISLA_LOCK_CAPTURE_DIR` saves captures.

Matugen migration checks:

```sh
python scripts/test-matugen.py
node bar/tests/palette.cjs
node bar/tests/settings.cjs
```

`bar/matugen-palette-regression.qml` accepts `ISLA_PALETTE_FIXTURES` with real Matugen dark/light palettes and `ISLA_TEST_OUTPUT` for Wayland captures. Use a temporary ISLA_CONFIG.

`python bar/tests/matugen-reload.py` verifies the production IPC command against a real isolated Quickshell instance and two atomic palette swaps; requires Matugen and Quickshell. It never changes the live wallpaper.

### Wallpaper audit regressions

`bar/wallpaper-view-regression.qml` exercises an isolated model, rapid preview
retargeting, busy/error/current states, partial-apply retry, reopen, contrast,
large type and reduced motion. `bar/wallpaper-surface-regression.qml` renders
both bar layouts and motion modes against the real library without applying a
wallpaper. Pass a temporary `ISLA_CONFIG`; `ISLA_TEST_OUTPUT` saves PNG evidence.
`bar/wallpaper-pipeline-regression.qml` covers model URLs, cache revisions and
stale requests. Require their explicit PASS lines, not only exit zero.

`python bar/tests/wallpaper-scanner.py` builds a temporary plugin and tests source
replacement and corrupt thumbnails offscreen. Set `ISLA_WPSCAN_BUILD` to an
existing build/import root to reuse a compiled plugin. `python scripts/test-matugen.py`
uses isolated fake binaries for transaction, partial failures and reduced-motion
commands; it never changes the live wallpaper.

`bar/wallpaper-apply-feedback-regression.qml` renders the loading→green/check
confirmation and validates error, reduced motion and suppression. Use temporary
`ISLA_CONFIG` and optional `ISLA_TEST_OUTPUT` for captures. `python
bar/tests/wallpaper-apply-protocol.py` runs the real QML Process/stdout protocol
with an isolated fake applicator, including partial failure and retry on reopen;
it never changes the desktop wallpaper. The production marker is emitted only
after generator preflight; confirmation follows publication/reload and the planned
transition window.

## Audio

```sh
python bar/tests/audio-backend.py
python bar/tests/audio-discovery-policy.py
python bar/tests/audio-meter-timing.py
ISLA_CONFIG=/tmp/isla-audio.json QT_QPA_PLATFORM=offscreen quickshell -p bar/mixer-surface-regression.qml
QT_QPA_PLATFORM=offscreen quickshell -p bar/audio-controller-regression.qml
python bar/tests/audio-live.py
```

The backend suite uses fake servers. The controller fixture reads real audio and
starts/stops meters without changing volume. The opt-in live test creates two
private null sinks, plays inaudible data and records only their monitors; it
checks volume, channels, mute, routing and signal peaks, removes all its nodes,
and verifies the user's default devices remain unchanged. Hardware profiles,
ports and digital passthrough are covered by command fixtures, not mutated on
the user's hardware. `ISLA_AUDIO_SHOTS` captures the view fixture on Wayland.

`bar/audio-apps-live-regression.qml` reads live streams without forwarding actions.
Set `ISLA_AUDIO_EXPECT_APPS=Spotify,Discord` to require those running applications;
`ISLA_AUDIO_SHOTS` captures playback, Hardware and large text on Wayland.
The meter timing test uses a private antiphase stereo tone and checks attack,
absence of false silence and release; it does not measure display FPS.

`bar/neon-regression.qml` renders the shared luminous material, media progress,
workspace selection, controls and OSD in a regular Wayland window. Checks zero
intensity and reduced-motion visibility; writes `/tmp/isla-neon-preview.png`.
Run with a temporary `ISLA_CONFIG`. The image has an opaque backdrop for alpha QA.

`bar/confirmation-indicator-regression.qml` checks the shared neon loading arc,
progressive success/error strokes, retry, interruption, hidden pause and reduced
motion. Use temporary `ISLA_CONFIG`; runs in a regular window without auth/network
actions. Wallpaper confirmation capture uses `ISLA_TEST_OUTPUT`.

`bar/stroke-language-regression.qml` (Tidemark) checks stroke tokens, `SpringValue`
(final state, interruption keeping velocity, reduced motion, hidden = still) and
`LevelStroke` (spring-followed level, tide mark hold/fall, head only while growing).
A failed `compare`/`verify` aborts silently in this harness, so it prints PASS only if
every function reaches its end. Use a temporary `ISLA_CONFIG`; offscreen is not visual QA.

CAVA: `ISLA_CONFIG=/tmp/isla-cava-test.json ISLA_TEST_OUTPUT=/tmp QT_QPA_PLATFORM=offscreen quickshell -p bar/cava-response-regression.qml`
verifica parser, agrupación, independencia del refresco y caída sin señal. Para
capturas usar Wayland; la señal de fixture es determinista, no una medición musical.

`python bar/tests/cava-stream.py` verifica selección aislada, sink real, ausencia/ambigüedad y limpieza normal/parent-death. Añadir `ISLA_CAVA_LIVE=1` al fixture CAVA comprueba la ruta con el player real en reproducción, sin cambiar reproducción ni rutas.

`ISLA_CONFIG=/tmp/isla-cava-centered-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/cava-center-regression.qml` recorre120alturas a escala1/1.25 y exige eje fijo en las5barras; también ejecutable Wayland.

### Clipboard interaction

`bar/clipboard-interaction-regression.qml` checks stationary-pointer/arrow
selection, stable preview geometry, rapid navigation through scrolling,
selection/highlight after model updates, collection editor focus/errors and
reduced motion. Run with `QT_QPA_PLATFORM=wayland` for native input validation;
`ISLA_TEST_OUTPUT` optionally saves screenshots and `ISLA_CLIPBOARD_IMAGE` can
point to a fixture image URL. It never reads or writes the desktop clipboard.
The library regression script uses private temporary data and mocked clipboard
commands, including exact saved image/text copy after history wipe and reload.

`bar/tests/clipboard-workflow-regression.sh` exercises the actual `Pill` host
with temporary clipboard commands/data, not just the standalone view. It checks
100-line text previews, wheel/pointer behavior inside the preview, a frozen
entry target, create/select collection by mouse and keyboard, save/confirmation,
full text and scroll after save, duplicate-name failure and editor cancellation,
remove from Saved, exact copy, motion reversal and reduced motion mid-transition.
Set `QT_QPA_PLATFORM=wayland` for native rendering and `ISLA_TEST_OUTPUT` to save
screenshots. No desktop clipboard/history is modified.

`bar/clipboard-design-regression.qml` covers the clipboard redesign at large
font1.5/600px, long collection navigation with animated scroll, section reversal,
destination Escape focus, empty/loading states, light theme and reduced motion.
Run with a temporary ISLA_CONFIG, QT_QPA_PLATFORM=wayland and optional
ISLA_CLIPBOARD_IMAGE fixture URL / ISLA_TEST_OUTPUT screenshot directory.
`clipboard-workflow-regression.sh` also checks quick save opens the contextual
organizer without decoding a full preview, and preserves exact copy/persistence.

## Media artwork and material continuity

`python bar/tests/media-presentation.py` checks retained artwork during real delayed
HTTP loads from a local server, stale-response cancellation, shared panel/ambient
progress, stable two-line metadata, missing/error art, hidden state, disabled
transitions and reduced motion. It uses temporary ISLA_CONFIG and synthetic SVG
art; it never controls playback. Set QT_QPA_PLATFORM=wayland and ISLA_TEST_OUTPUT
to an existing directory for native initial/intermediate/final/material captures.

`python bar/tests/settings-media-routing.py` injects a mock player into a temporary
copy. It also checks shared artwork and its retention during panel closure in
split/compact with normal/reduced motion; do not run its QML fixture directly.
`settings-controls-regression.qml` covers selected-row menu anchoring on/off and
keyboard navigation. Run native focus tests sequentially to avoid focus contention.
The settings integration test saves/discards the three visual options in an
isolated configuration.

## Swiftify-inspired media motion

`bar/swiftify-media-regression.qml` checks playback cover/button retargeting,
lyrics wave/seek/keyboard/capability guards, manual browsing, large seeks, new
lyrics before their first timestamp, reduced/disabled transitions and hidden state.
Use a temporary `ISLA_CONFIG`; run offscreen for invariants and Wayland for input
and captures (`ISLA_TEST_OUTPUT` points to an existing directory).

`bar/media-ambient-regression.qml` checks the low-resolution artwork field,
shared crossfade, retained phase, pause/resume and hidden/settled/reduced guards.
Neither fixture changes personal playback. See `docs/swiftify-2026-10-17/REPORT.md`.

Player redesign (2026-10-17): `python bar/tests/lyrics-backend.py` serves private
LRCLIB-like HTTP responses and exercises exact/loose/search fallback, ranking,
stale responses, close/reopen, transient failures and recoverable/exhausted timeouts.
The opt-in `ISLA_LYRICS_TEST_CASE=live quickshell -p bar/lyrics-controller-regression.qml`
queries LRCLIB for the fixed public test metadata; it does not control playback.
Always use temporary `ISLA_CONFIG`. `bar/media-layout-regression.qml` checks the
new right-column timeline and controls at three font scales; `swiftify-media`
also checks bundled icon family/native button input and loading/error copy.
Evidence: `docs/swiftify-2026-10-17/redesign/REPORT.md`.

Refinement2026-10-17: `swiftify-media-regression.qml` also checks48radial bands,
zero/moderate/full audio excursions, active/outgoing lyric glow, following after
3.2s of manual inactivity and reopening. `swift-media-timeline-regression.qml`
checks the Swiftify-inspired timeline pointer/keyboard/state contract.
`media-clock-regression.qml` checks sparse position notifications, pause, external
seek, playback rate and reopen. Opt-in `ISLA_MEDIA_CLOCK_CASE=live` samples Spotify
MPRIS without controlling playback. Use temporary ISLA_CONFIG for all fixtures.

Artwork colors: `python bar/tests/artwork-palette.py` checks the isolated helper
and real local/HTTP extraction. `bar/media-palette-regression.qml` checks shared
accent/fade, latest source, error/empty fallback and reduced motion. Use temporary
ISLA_CONFIG and ISLA_TEST_OUTPUT for native captures. MediaPalette extraction is
once per artwork URL, cached, and does not alter Matugen or personal playback.

Media fixes2026-10-18: `python bar/tests/media-palette-recovery.py` checks actual
HTTP cancellation, bounded retries and watchdog with an isolated cache/config.
`swift-media-timeline-regression.qml` now requires exact immediate progress for
small/large seeks and natural advances, obsolete-drag cancellation, unsupported
length clock stop and correct neutral endpoints. `media-palette-regression.qml`
checks the main button's palette color and the interior neon field as well.

## Compact layout audit

`bar/compact-island-regression.qml` also checks cover-only narrow layout, readable
short metadata, font scaling, oversized workspace rail width recovery, selection
inside workspace cells, keyboard/whole-row pointer activation, rapid panel
retargeting and reduced motion enabled during a morph. Always use temporary
ISLA_CONFIG. `ISLA_COMPACT_SHOTS` saves fixture captures; optional
`ISLA_COMPACT_FRAMES=1` samples two calendar open/close cycles and logs elapsed
times and geometry. These are irregular Wayland-rendered scene samples, not
presentation FPS or a complete compositor recording.

Compact media follow-up: `compact-island-regression.qml` checks the compact
progress ring, paused external seek and unknown duration. `cava-center-regression.qml`
also checks shared small-CAVA neon activation by audio energy, pause/reduced
shutdown and preserves five-bar centering at scales1/1.25. Optional
ISLA_TEST_OUTPUT saves native fixture images.

`bar/rest-media-transition-regression.qml` checks the opt-in compact/split rest
choreography: retained/latest artwork, metadata crossfade, same-album track
changes, stable cover geometry, rapid replacement, hidden/reopen, reduced motion
and disabled transitions. Use temporary ISLA_CONFIG; QT_QPA_PLATFORM=wayland
and ISLA_TEST_OUTPUT for native fixture captures. No personal playback changes.

## Connectivity redesign

`bar/connectivity-design-regression.qml` checks mock Wi-Fi/Bluetooth actions,
mode retargeting, disabled/empty states, source1.5 text, credential states and
reduced reopening. Tab/Shift+Tab must reveal Bluetooth actions without manual
scroll. Use temporary `ISLA_CONFIG`, Wayland for native input/rendering and
optional `ISLA_TEST_OUTPUT` for screenshots. No radio changes are made.

`bar/connectivity-host-regression.qml` checks the actual pill host geometry,
split/compact rest heights, interrupted reopening, unload and reduced motion.
It reads existing connectivity services but never invokes their actions.

`bar/wallpaper-media-header-regression.qml` checks music at the wallpaper body's
actual inset width, UI/font scales, narrow and no-player states. Optional
`ISLA_TEST_OUTPUT` saves native fixture screenshots. `bar/media-dock-surfaces-regression.qml`
forces a fixture companion present and verifies absorption before wallpaper,
overview and launcher, then close/release in normal/reduced motion. Use temporary
ISLA_CONFIG and Wayland; neither changes wallpaper or personal playback.

`bar/workspace-width-regression.qml` checks 5→6 growth through intermediate widths,
selection bounds, rapid reversal, split/integrated styles and reduced/hidden/
disabled animation. Use temporary ISLA_CONFIG and Wayland for native captures
(`ISLA_TEST_OUTPUT`). No real workspace switches.

## Design fixes: elapsed time and early input

`bar/frame-time-regression.qml` advances the production spring manually at
144/60/30/20/10 Hz, motion scales 0.25/1/2, isolated late frames, retarget,
suspension, invalid intervals and reduced motion. It checks elapsed-time
consistency and bounded settling; it does not measure compositor FPS.

`bar/launcher-focus-regression.qml` uses the production Pill in a Wayland Window:
focus within 120 ms after field load, typing without clicking, closing without
reclaiming focus, cancelled close, unload and reduced motion. Run serially with
other native focus fixtures and temporary ISLA_CONFIG. Its Window does
not certify layer-shell keyboard policy.

`bar/calendar-design-regression.qml` checks translated Spanish source dates,
forecast weekdays, month titles, targets at scales 0.8/1/1.25, mouse navigation
across year boundaries and Return/Space. Run with en_US and es_DO process locales
to catch accidental dependence on the ambient date locale. Require explicit PASS
and no FAIL in every log, not just exit 0.

## Material readability and active ink

`bar/material-accessibility-regression.qml` checks reduced transparency, stored
glass alpha preservation/restoration, discard, split/compact and a 175% editor.
Use temporary ISLA_CONFIG; Wayland is required for native inspection.
ISLA_PALETTE_FIXTURES accepts `docs/design-accessibility-2026-10-26/palettes.json`,
ISLA_PALETTE_INDEX selects its palette and ISLA_CAPTURE_HOLD_MS keeps the native
window available after PASS for grim. Offscreen is not visual QA.

`bar/matugen-palette-regression.qml` checks 426 active intensities across those
six palettes. It checks semantic pairs and the best available active ink on
four gradient faces; it does not certify a 4.5 ratio at every intensity or on
arbitrary transparent backgrounds. Measurements and native captures are in
`docs/design-accessibility-2026-10-26/REPORT.md`. Settings integration also tests
reduceTransparency save/discard; settings UX checks Appearance without search.

## System updates portal

- `python bar/tests/system-updates.py`: ten isolated backend tests with fake PATH
  and temporary Git remotes; no real installations.
- `python bar/tests/updates-service.py`: mocked bridge/notifier, partial errors,
  persistent notification dedupe across two processes, action and launch feedback.
  Also verifies install guards, malformed output/process failure, preserved results
  and recovery. Offscreen logic test, not visual QA.
- `ISLA_TEST_OUTPUT=/tmp/isla-updates-qa python bar/tests/updates-ui.py`: native
  Wayland, injected controller, navigation/search/actions, dirty shell protection,
  unavailable Flatpak, busy state, 1000×700/640×560 and font scales 1/1.75.
  Normal motion covers intermediate package disclosure, rapid reversal/navigation,
  reduced motion enabled mid-flight and hidden page/window settling; activity
  must stop while hidden or reduced. Captures are samples, not FPS measurements.
- `python bar/tests/settings-integration.py`: includes update preference save/discard.

Read-only live check: `qs -p bar ipc call updates check`, then `... updates state`.
`... updates open` opens the portal. Never run install/launch for automated tests;
updates require the user's deliberate action and native terminal confirmation.

`python bar/tests/updates-notice.py` exercises the real Notifs singleton on a
private D-Bus session with temporary state: DND, open center, saved notice and
working local action after process restart. It never sends notices to the user bus.

## Cuerpo

Demo aislada: `quickshell -p bar/body-demo.qml` (1–5 ánimo, M música, B respiración,
R reducir movimiento, Esc salir). Reiniciar tras recompilar el shader:
`(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)`.

- `node bar/tests/body-brain.cjs`
- `ISLA_CONFIG=/tmp/isla-body-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-regression.qml`
- Para comprobar ShaderEffect con renderizador real offscreen:
  `ISLA_CONFIG=/tmp/isla-body-test-gl.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl quickshell -p bar/body-regression.qml`
- `/usr/lib/qt6/bin/qmllint bar/body/*.qml bar/body-demo.qml bar/body-regression.qml`

Software offscreen omite shader; no equivale a QA visual. Capturas Wayland,
recuento Timer y límites: `docs/cuerpo-fase1-2026-10-30/REPORT.md`.

### Cuerpo · gota mensajera (Fase 2)

- `node bar/tests/body-drop.cjs`: estados, interrupciones, cuello/residuo, captura, reduce y dt.
- `ISLA_CONFIG=/tmp/isla-drop-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-drop-regression.qml`
- Shader: añadir `QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` al comando anterior.
- Demo: G soltar/llamar, D entregar; arrastrar `captura.png` arma la recogida.
- Evidencia Wayland y límites: `docs/cuerpo-fase2-2026-10-30/REPORT.md`.

### Cuerpo · pill real (Fase 3)

- `ISLA_CONFIG=/tmp/isla-body-pill.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl quickshell -p bar/body-pill-regression.qml`
- Repetir sin variables gráficas para Wayland. Offscreen software verifica fallback.
- Geometría, material al abrir/cerrar e interrumpir, Fluid, compact/escala,
  inactividad bajo cambios de puntero/ancho, movimiento/transparencia reducidos.
- Exigir `PASS: BodyPill` y ausencia de `FAIL:`; QtTest puede dejar exit=0 al fallar.
- Shader recompilado requiere reiniciar la instancia (reload conserva caché qsb).
- Evidencia y alcance: `docs/cuerpo-fase3-2026-10-30/REPORT.md`.

### Cuerpo · eventos y archivos (Fase 4)

- `node bar/tests/body-file.cjs`: rutas locales y argv literal.
- `python bar/tests/body-messenger.py`: abridor falso, clic/teclado, suspensión, archivo pendiente y reduceMotion.
- `ISLA_CONFIG=/tmp/isla-events.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-events-regression.qml`
- BodyPill incluye reloj local, foco, música y opciones. Repetir en Wayland.
- Capturas guardadas al cerrar Satty y Recording.saved ofrecen el archivo al monitor enfocado.
- Activación para un atajo de teclado: `qs ipc -p ~/.config/quickshell/bar/shell.qml call island bodyOpen`.
  Ejecuta únicamente si hay archivo guardado y disponible; no configura un atajo global.
- Un archivo pendiente por monitor; no mueve ni borra. Las ofertas nuevas se descartan mientras está ocupado.
- Evidencia y límites: `docs/cuerpo-fase4-2026-10-30/REPORT.md`.


## Agua W1 · vidrio único opt-in (2026-10-31)

Usar un ISLA_CONFIG temporal inexistente: el fixture comprueba el default false,
rechazo de valores no booleanos y activa waterBody sin guardar configuración.

```sh
ISLA_CONFIG=/tmp/isla-water-test.json QT_QPA_PLATFORM=wayland qs -p bar/water-body-regression.qml
ISLA_CONFIG=/tmp/isla-water-test-gl.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl qs -p bar/water-body-regression.qml
node bar/tests/body-brain.cjs
(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)
/usr/lib/qt6/bin/qmllint bar/body/PillBody.qml bar/body/BodyShader.qml bar/body/BodyEngine.qml bar/components/PillMaterial.qml bar/Pill.qml bar/water-body-regression.qml
```

Exigir PASS explícito y ausencia de FAIL. En software comprueba sólo fallback,
cableado de geometría/uniformes y reloj determinista: **no** prueba compilación,
caché ni exposición real. En RHI comprueba exposición constante al abrir/cerrar
launcher/media/calendar/utils, geometría de captura, sombra del material sin FBO,
caché quieto, error real de shader, movimiento reducido e interrupción. El fixture
no prueba píxeles ni coste de GPU. Reiniciar qs después de recompilar el qsb.

Comparar además body-pill, frame-time, pill-geometry, pill-composition,
pill-interface, content-hold, surface-swap-close y surface-materialize con
waterBody=false. La ejecución aislada de esta fase está en
`docs/agua-w1-2026-10-31/BASELINE.md` y `REPORT.md`.

En la sesión Wayland real, registrar `pgrep -ax qs` (shell `qs -d`), GPU reposo,
launcher quieto y morph; sample-process.py aporta CPU/PSS. gpu-recording.py prueba
el grabador con backend falso, no mide utilización GPU. qml-performance.py mide
su fixture de composición, no FPS físicos; frame-time-regression es determinista.
Capturar antes/después reposo, launcher, media, calendario, notificación y ambos
temas, más ≥6 fotogramas reposo→launcher, con el método Wayland descrito arriba.
No confundir offscreen con QA. El entorno W1 no permite sockets Wayland ni GPU;
la sombra exterior, invalidez del caché en píxeles y rendimiento quedan pendientes.


### Agua W1 · corrección R1 (2026-10-31)

Sustituye la descripción anterior del alcance del fixture: ahora comprueba en
software decoraciones conservadas, seis cuadros de quietud, render directo sin
layer, continuidad del muelle de reposo y renderInputs null sin caché. Su rama
RHI añade grabImage del shader: sombra independiente de outsideOpacity, pico
≤0.14 y proporcional a shadowExposure, ausencia de sombra en reposo y dithering
espacial también en el interior barato. Comprueba alineación física del caché y
que bodyBreath mantiene sourceItem=null sin alternar captura/capa.

Repetir los comandos W1 anteriores con ISLA_CONFIG nuevo. Exigir ambos PASS R1
y el PASS final correspondiente al backend, sin FAIL. Software no ejecuta las
aserciones de píxeles, respiración en producción ni ShaderEffectSource real.
La sombra exterior ya está implementada; su aspecto y ausencia de segunda placa
siguen **no verificados** hasta capturar Wayland con el compositor real.

### Agua W3 · campo compartido de gotas (2026-10-31)

Desde la raíz, sin tocar la shell real. Cada lanzamiento es un proceso nuevo
para invalidar el qsb cacheado. No guardar Config desde los fixtures.

```sh
(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)
task_dir=$(mktemp -d /tmp/agua-w3-XXXXXX)
mkdir -m 700 "$task_dir/runtime" "$task_dir/cache"
export ISLA_CONFIG="$task_dir/missing.json"
export XDG_RUNTIME_DIR="$task_dir/runtime" XDG_CACHE_HOME="$task_dir/cache"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=
for test in water-body water-drop body-pill body frame-time pill-geometry pill-composition content-hold surface-swap-close surface-materialize; do
    timeout -k 5 90 quickshell -p "bar/$test-regression.qml"
done
rg -l 'FluidCompanion|FluidNeck|FluidMediaCompanion' bar/*regression*.qml
# Ejecutar también los fixtures enumerados por rg que no estén en el bucle anterior.
QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl timeout -k 5 90 quickshell -p bar/water-body-regression.qml
QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl timeout -k 5 90 quickshell -p bar/water-drop-regression.qml
node bar/tests/body-brain.cjs
/usr/lib/qt6/bin/qmllint bar/body/PillBody.qml bar/body/BodyShader.qml bar/components/FluidCompanion.qml bar/Pill.qml bar/windows/IslandOverlay.qml bar/water-drop-regression.qml
```

Exigir PASS explícito, ausencia de FAIL y salida 0. W3 usa disponibilidad fingida
en software para verificar que ambos Loader están vacíos y el layer de recorte
apagado; después conecta el renderer real para comprobar su respaldo. No presenta
esa disponibilidad fingida como compilación, render ni fallo real del shader.
La inversión abrir→cerrar→abrir conserva geometría (<=1 px) y velocidad al
retargetear. Se registra aparte el desplazamiento ordinario a 60 Hz; no se exige
que un recorrido físico completo avance sólo 1 px por cuadro.

En RHI, grabImage cruza el cuello por y=80, x=150..205 del fixture: exige relleno
en el hueco y salto adyacente de luminancia Rec.709 <=32 unidades de 255.
El límite admite gradiente/lente y dithering; detecta una costura brusca, no
certifica todo el contorno ni la continuidad temporal. También verifica caché
quieta, invalidación por geometría y Loader tras error real del shader.

Resultado local: 17 fixtures PASS; settings-async no carga PanelWindow en
offscreen. RHI no crea contexto OpenGL. Caché real, píxeles, GPU/PSS y QA Wayland
siguen pendientes; Claude realiza esa QA. Informe: docs/agua-w3-2026-10-31/REPORT.md.


## Agua W4 · decoraciones (2026-10-31)

Usar un ISLA_CONFIG inexistente y directorios runtime/cache temporales (runtime
con modo 0700); no reiniciar la shell de producción por la caché de qsb.

```sh
(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)
ISLA_CONFIG=/tmp/agua-w4-nonexistent.json XDG_RUNTIME_DIR=/tmp/agua-w4-runtime XDG_CACHE_HOME=/tmp/agua-w4-cache QT_QPA_PLATFORM=offscreen timeout 90 quickshell -p bar/water-decor-regression.qml
```

Repetir para water-body, water-drop y los fixtures que devuelve
`rg -l "PillMaterial|FluidCompanion" bar/*regression*.qml`; ejecutar además
`node bar/tests/body-brain.cjs` y qmllint sobre los QML tocados.
Repetir water-body/water-drop con `QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl`.
WaterDecor valida descarga real del árbol decorativo, fallback, recepción de la
gota, conservación del arte al cerrar/invertir, continuidad de muelles y reposo.
La rama RHI añade píxeles de arte y error real de shader. Offscreen software no
prueba el shader ni costuras; RHI sin contexto tampoco equivale a PASS visual.
Resultados y fallos reproducidos sobre W3: `docs/agua-w4-2026-10-31/REPORT.md`.


## Gestos F1 · abrir y cerrar tirando de la pill (2026-11-06)

Desde la raíz, con configuración inicialmente inexistente y directorios aislados:

```bash
gesture_test_dir=$(mktemp -d /tmp/isla-gestos-f1.XXXXXX)
mkdir -m 700 "$gesture_test_dir/runtime"
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
  ISLA_CONFIG="$gesture_test_dir/shell.json" \
  XDG_RUNTIME_DIR="$gesture_test_dir/runtime" \
  XDG_CACHE_HOME="$gesture_test_dir/cache" \
  XDG_STATE_HOME="$gesture_test_dir/state" \
  timeout 90 quickshell -p bar/pull-gesture-regression.qml
```

La prueba usa press/move/release reales de QtTest sobre Pill y `manualStep` sobre
el mismo PillMorphMotion de producción. Comprueba umbral y dirección, seguimiento
1:1, ancho/radio y banda elástica compartida con Slider, regresión de velocidad de
80 ms, fling, retorno corto, primer cuadro extrapolado, cierre y captura de un
muelle que abre o cierra. También comprueba cierre externo durante el gesto,
scroll de lista fuera del tope, fin por 120 ms de silencio, reduceMotion,
desactivación, tamaño final del contenido y reposo sin integrador, temporizador
del gesto ni capa del contenido. Guarda los ajustes en el ISLA_CONFIG temporal,
comprueba el JSON y discard, y carga Edots > Movimiento en español e inglés,
incluida su búsqueda. No usar el archivo de configuración habitual para este test.

`gestures.enabled` activa los gestos; `gestures.pullTarget` admite auto, utils,
media, notifs y calendar. Auto elige media sólo si hay reproductor disponible
mostrado; en otro caso elige utils. Una surface abierta se agarra desde sus
márgenes libres o el texto de SurfaceHeader; los controles conservan su entrada.
La rueda por pasos no inicia gestos. Un touchpad puede cerrar desde una lista
cuando está arriba del todo; los campos de texto y faders conservan su entrada.
WheelHandler.active termina las fases nativas y un Timer de una sola ejecución
cubre dispositivos sin fin de fase. El IPC opcional de tres dedos queda fuera
de esta implementación; no se ha modificado Hyprland.

Ejecutar además surface-materialize, content-hold, frame-time, compact-island,
overlay-native-input, notification-breath y todos los archivos devueltos por:

```bash
rg -l 'PillMorphMotion|SurfaceRouter|IslandOverlay' bar/*regression*.qml
```

Usar un directorio temporal nuevo por prueba. Comparación previa y final, límites
del backend offscreen y archivos concretos: `docs/gestos-f1-2026-11-06/REPORT.md`.

QA Wayland pendiente para Claude (offscreen no la sustituye): en compact/split,
auto/utils/media/notifs/calendar y escalas de monitor distintas, arrastrar más
allá de la región inicial de la pill, invertir y volver a atraparla. Comprobar
que el movimiento continúa fuera de la máscara de reposo por el agarre implícito
y que al soltar se restablece la entrada normal. La máscara/política de entrada
en reposo conserva el código previo; no se amplía a pantalla completa al pulsar.
Probar scroll con fases nativas y pausa de 120 ms; las listas desplazadas deben
conservar su scroll. Probar cabeceras, sliders, botones, texto, fondos, hover,
peek, Escape, clic fuera, BodyMessenger y DnD de archivos. Revisar la continuidad
de radio, materialización y velocidad con captura visual. Esta fase no reinicia
ni manipula la shell real.

## Gestos F1 · corrección 1 (2026-11-06)

Esta sección sustituye la omisión anterior del IPC y precisa la política de
entrada. Mientras candidate/active de puntero está en curso y no es scrolling,
se conservan el foco y el modo de máscara anteriores al press. La región pill
usa la geometría real y objetivo, incluido el sobreestiramiento. Soltar abierto
activa Exclusive/full y Escape inmediatamente; soltar cerrado restaura pill.
El scroll conserva su política normal. El contenido mantiene su layout final,
queda oculto hasta progreso/espacio 0.6 y se revela hacia 0.95; al cerrar se
retira primero. WheelEvent.inverted normaliza los deltas físicos del touchpad.

Con el mismo aislamiento descrito arriba y un directorio nuevo por fixture,
ejecutar también:

```bash
timeout 90 quickshell -p bar/overlay-input-policy-regression.qml
timeout 90 quickshell -p bar/rolling-elastic-regression.qml
```

La primera prueba conserva foco/máscara al abrir y cerrar durante el press,
comprueba la región sobreestirada y la recuperación de teclado/Escape al soltar.
La segunda comprueba la función JS compartida (asíntota, pendiente inicial y
simetría), además del clamp, estiramiento y retorno de Slider y AudioFader.
pull-gesture-regression comprueba esos cambios sobre Pill con eventos QtTest,
contenido ya cargado, deltas invertidos y no invertidos, y rutas IPC.

IPC disponible en el target island: `pull(auto|utils|media|notifs|calendar)`
alterna la surface en el monitor enfocado con el muelle normal. Auto usa media
si está disponible y mostrada; en otro caso utils. Ejemplos para la QA de Claude
(no se han ejecutado contra la shell real):

```bash
qs -c bar ipc call island pull auto
qs -c bar ipc call island pull calendar
```

Ejemplo para Hyprland con configuración hyprlang, según la
[wiki versionada](https://wiki.hypr.land/0.52.0/Configuring/Gestures/):

```ini
gesture = 3, down, dispatcher, exec, qs -c bar ipc call island pull auto
```

Equivalente para configuración Lua, según la
[wiki actual](https://wiki.hypr.land/configuring/core/binds/gestures/):

```lua
hl.gesture({ fingers = 3, direction = "down", action = function()
    hl.exec_cmd("qs -c bar ipc call island pull auto")
end })
```

Son ejemplos de documentación: no se ha editado la configuración del usuario.
Este gesto del compositor dispara el toggle al terminar, no envía deltas 1:1.
La QA Wayland de Claude debe repetir el arrastre lento fuera de la región
inicial, sobreestiramiento, cierre sin captura residual, Escape/teclado tras
soltar, contenido en ambos sentidos, touchpad con/sin natural scrolling e IPC
con el monitor enfocado. La prueba Python nativa usa ahora focus en lugar de
Appearance eliminada. Offscreen no verifica el agarre de una layer surface.

## Gestos F2 · gotas y notificaciones (2026-11-06)

`drop-gesture-regression.qml` prueba los motores reales con press/move/release,
pasos manuales y eventos de ratón de QtTest: notificación arriba/horizontal/abajo,
velocidad, salida del texto antes del recipiente, pausa y reanudación de la
expiración real, prioridad de la notificación tocada, seguimiento y rotura de
media, microgota y restauración al cambiar pista/reproductor, gotas protegidas,
brote de las cuatro rutas y reposo sin reloj activo. Incluye movimiento reducido,
gestos desactivados, cambios de ajuste durante un descarte y rechazo del router.

Desde la raíz, usar un entorno nuevo por fixture; el archivo de configuración
debe ser inexistente al empezar:

```bash
gesture_check() {
    local gesture_dir
    gesture_dir="$(mktemp -d /tmp/isla-gestos-f2.XXXXXX)"
    mkdir -p "$gesture_dir/runtime" "$gesture_dir/cache" "$gesture_dir/state"
    chmod 700 "$gesture_dir/runtime"
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
      ISLA_CONFIG="$gesture_dir/config.json" \
      XDG_RUNTIME_DIR="$gesture_dir/runtime" \
      XDG_CACHE_HOME="$gesture_dir/cache" \
      XDG_STATE_HOME="$gesture_dir/state" \
      timeout 90 quickshell -p "$1"
}
gesture_check bar/drop-gesture-regression.qml
for fixture in $(rg -l 'FluidCompanion|IslandNotification|Notifs' bar/*regression*.qml); do
    if [ "$fixture" != bar/drop-gesture-regression.qml ]; then
        gesture_check "$fixture"
    fi
done
gesture_check bar/pull-gesture-regression.qml
```

Comprobar tanto el código de salida como los marcadores PASS/FAIL. La línea base
de F2 ya falla en `interaction-surfaces` (Workspaces eliminado), `updates-service`
(marcador FAIL aunque exit=0) y `settings-async` (sin backend PanelWindow en
offscreen); sus resultados se conservan tras F2. Detalle y evidencia en
`docs/gestos-f2-2026-11-06/REPORT.md`.

La QA Wayland corresponde a Claude: comprobar captura fuera de la región
inicial, foco/máscara estables mientras se arrastra, clic/hover y continuidad
visual de cuello, brote y microgota. `bar/tests/vpointer.py` queda reservado a
esa QA; este fixture no lo ejecuta ni reinicia la shell ni modifica Hyprland.


## Actividades · 2026-11-06

Desde la raíz, el runner crea HOME, configuración inexistente, runtime, caché y
estado temporales por fixture. Quita WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE
y DBUS_SESSION_BUS_ADDRESS; nunca consulta la shell real. Comprueba los marcadores
FAIL además del exit code (algunos fixtures antiguos terminan con 0 tras fallar).

```bash
python -I bar/tests/activity-qml.py
python -I bar/tests/activity-cli.py
python -I bar/tests/activity-fish-button.py
fish -n bar/scripts/fish/isla.fish
/usr/lib/qt6/bin/qmllint bar/Singletons/Activities.qml \
  bar/components/ActivityDropContent.qml bar/components/FluidRecordingCompanion.qml \
  bar/components/ActivityView.qml bar/components/PillPullGesture.qml \
  bar/Singletons/Notifs.qml bar/Singletons/SystemUpdates.qml \
  bar/windows/IslandOverlay.qml bar/shell.qml bar/settings/EdotsWindow.qml \
  bar/settings/SettingsPage.qml bar/settings/FishIntegration.qml \
  bar/activities-regression.qml bar/tests/activity-fish-button.qml
```

`activity-qml.py` acepta rutas adicionales de fixtures. Para repetir la comparación
de gotas, notificaciones, pull/drop y ajustes:

```bash
python -I bar/tests/activity-qml.py \
  bar/centered-companion-regression.qml bar/companion-continuity-regression.qml \
  bar/drop-gesture-regression.qml bar/interaction-surfaces-regression.qml \
  bar/notification-attention-regression.qml bar/notification-drop-regression.qml \
  bar/notification-priority-regression.qml bar/notification-routing-regression.qml \
  bar/notifs-surface-regression.qml bar/pull-gesture-regression.qml \
  bar/session-companion-regression.qml bar/settings-async-regression.qml \
  bar/settings-companion-regression.qml bar/updates-notice-regression.qml \
  bar/updates-service-regression.qml bar/water-decor-regression.qml \
  bar/water-drop-regression.qml
```

La línea base previa y posterior a actividades coincide: 14 PASS; fallan ya
`interaction-surfaces` (Workspaces), `settings-async` (PanelWindow offscreen) y
`updates-service` (compare). No asumir PASS por exit=0.

La prueba nueva cubre validación, ráfagas, prioridad, ocho entradas, métodos IPC,
expiración controlada, notificaciones QObject, SystemUpdates, lista compartida,
gesto de gota, destino auto, swell/ErrorShake, movimiento reducido, Edots bilingüe
y reposo. El runner intenta además el SocketServer sólo en su runtime temporal;
si no puede escuchar, muestra BLOCKED. El CLI usa un socket simulado y también
intenta AF_UNIX real: EPERM produce SKIP explícito. En este sandbox ambos binds
están bloqueados; los métodos IPC se prueban directamente, sin llamar `qs ipc`
contra una instancia real. Los botones fish sí ejecutan su componente y procesos
reales, y verifican crear/quitar el enlace en HOME temporal.

Reposo: el publicador de 34 ms y la única expiración son one-shot; no corren sin
entradas. El listener espera eventos del sistema, sin polling. El contenido sin
actividad oculta ConfirmationIndicator (sin arco ni layer), y los muelles y el
motor de gota se detienen al asentarse. Con una actividad indeterminada estable,
sólo anima el arco existente; la lista oculta no anima indicadores. Duración en
la lista usa un reloj de 1 s sólo mientras esa página está abierta y hay procesos
en curso; se detiene al cerrar, cambiar de página o terminar el último proceso.
Offscreen no prueba píxeles, materiales ni captura de una layer surface: Claude
hace la QA Wayland, incluida convivencia con grabación/foco y reabsorción.
La API, evidencias y relevo están en `docs/actividades-2026-11-06/REPORT.md`.

## Momentos de dispositivo (dispositivos-2026-11-06)

`device-moments-regression.qml` (~25 s, tiempos reales de los Timers de un disparo)
cubre con datos simulados: ajustes `devices.*`, Bluetooth (conexión, hover que
pausa 3,5 s, baterías, desconexión, batería baja una vez por conexión), corriente
(2 s, enchufar/desenchufar), USB (líneas del monitor, abrir, expulsar con
`runner` simulado y errores), privacidad (histéresis de 400 ms, nombres, enlace
breve) y cola/prioridad (surface abierta, pantalla completa, DND, gesto,
notificación, caducidad). Ejecutar con ISLA_CONFIG inexistente y XDG_* temporales:
`python /tmp/gestos-f1-validate.py <fase> bar/device-moments-regression.qml`.
No se prueba offscreen: cableado de IslandOverlay (no hay backend PanelWindow),
fuentes vivas de Bluetooth/UPower/Pipewire/udisks, hover/clic reales, píxeles.
Reposo: sólo Timers de un disparo mientras hay momento o transición de
privacidad; el único proceso nuevo es `scripts/isla-device-storage`
(`udisksctl monitor`, sólo con `devices.storage`). Autocomprobación del monitor:
`python3 bar/scripts/isla-device-storage --self-test`. Detalle en
`docs/dispositivos-2026-11-06/REPORT.md`.

## Las apps nacen de la isla (launch-flight-regression)

`bar/launch-flight-regression.qml` prueba el motor de vuelo (`components/LaunchFlight.qml`
+ `LaunchFlight.js`) con `manualStep`, eventos `openwindow` / `activewindowv2` simulados y un
proveedor de geometría inyectado: no toca Hyprland ni lanza apps. Cubre casado de clase,
cero retraso (orden `controller.launch` -> `Apps.announceLaunch` por texto), secuencia
brote -> rotura con residuo -> vuelo -> retarget (posición ±1·s, velocidad ±10 %) -> llegada,
cobertura <= 220 ms, 6 s sin ventana, ventana existente, workspace oculto, otro monitor,
reduceMotion / ajuste apagado / pantalla completa y reposo sin escena. El cableado de
`IslandOverlay` no es instanciable offscreen: sólo se comprueba por texto y `qmllint`.
Ejecutar: `python /tmp/gestos-f1-validate.py <fase> bar/launch-flight-regression.qml`
(ISLA_CONFIG inexistente). La QA Wayland real (cuello, vidrio, `decoration:rounding`) sigue pendiente.

## water-reactive-regression (material vivo)
Reglas numéricas (tinte <= 12 % y contraste con portadas extremas en temas oscuro/claro/real, onda
proporcional/acotada/sin apilar, envolvente de graves 40/220 ms y +-8 %) más PillBody en vivo: onda ~450 ms,
0 cuadros en reposo/pausa/tinte asentado, cruce con muelle sin rebasar, relajación ~1,2 s, fallbacks
(reduceMotion, waterBody=false, shader roto, software) y cableado de OSD en `Pill`.
Ejecutar: `python /tmp/gestos-f1-validate.py <fase> bar/water-reactive-regression.qml` (y con
`QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` para la rama en vivo; en software sólo corren las reglas
puras y los fallbacks). Offscreen no es QA visual; falta QA Wayland del brillo, tinte y anillo.

Vuelo de app (escenario aislado, sin lanzar apps): `ISLA_CONFIG=$T/shell.json ISLA_STAGE_OUT=$T QT_QPA_PLATFORM=offscreen quickshell -p bar/launch-flight-stage.qml`
guarda fotogramas `stage-<ms>-<fase>.png`. Offscreen sirve para revisar forma y trayectoria; no es QA Wayland.

## files-integration-regression + files-ipc (explorador de archivos, composición)
`ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-integration-regression.qml` monta `FilesView`
sobre un fixture en mktemp (papelera aislada con `XDG_DATA_HOME`, abridor stub): historial (Alt+←/→, Backspace),
abrir un archivo con espacios y `#` (un solo argv al abridor), diálogo de conflicto (Omitir/Mantener ambos/Reemplazar/Esc),
papelera + Ctrl+Z, menú contextual, carpeta nueva/renombrar, enlace a `Config.files` (Ctrl+H, vista lista/cuadrícula),
carpeta borrada bajo la vista (fallback + aviso), aviso de elementos no mostrables y Ctrl+W. Se niega a correr si
`ISLA_CONFIG` no está en /tmp (guarda ajustes). `python bar/tests/files-ipc.py` arranca `bar/files-test-host.qml` aislado
y comprueba `ipc call files open|toggle|close` (relativa/inexistente = false, archivo abre su carpeta, toggle x2 sin ventanas).
Offscreen es lógica, no QA visual: ventana flotante, cristal, tamaño/centrado (windowrule) y `xdg-open` quedan para QA Wayland.

## Explorador de archivos: suite completa (2026-11-07)
Todas las QML se lanzan con `ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen timeout 300 qs -p bar/<nombre>.qml`
(nunca con el HOME real) y terminan con `PASS:` en el log. Las de Python no necesitan shell.

| Prueba | Cubre |
| --- | --- |
| `file-ops-regression.qml` | cola de `FileOps` (FIFO, copiar/mover/papelera/renombrar, deshacer, cancelar, conflictos, miniaturas fuera de cola); 13 escenarios. Puede dar falso rojo con la máquina muy cargada (timeout fijo) |
| `files-model-regression.qml` | `PathUtil` y `FilesModel`: carpeta vacía, 20000 archivos, symlink roto, filtro, ocultos, nombres raros, `pathLost` |
| `files-views-regression.qml` | selección por ruta (clic/Ctrl/Shift/teclado/banda), lista y cuadrícula, reordenación, miniaturas con `thumbResolver`, 20k = 41 delegados |
| `files-nav-regression.qml` | migas, edición/validación de ruta, lugares XDG, unidades `lsblk`, JSON malformado, barra lateral |
| `files-integration-regression.qml` | composición de `FilesView` (ver sección anterior) |
| `files-interaction-regression.qml` | QuickLook (origen/retorno/contenido/reduceMotion), búsqueda al teclear, carga útil y umbral de arrastre, drops internos/ajenos, banda; 10 pruebas |
| `files-motion-regression.qml` | apertura monótona, entrada direccional, navegación interrumpida, resalte deslizante, fundido de migas/miniaturas, ventana oculta, reduceMotion, interrupción hacia 20k; 10 pruebas |
| `python3 bar/tests/files-helper.py` | `services/files_helper.py` (NDJSON): listado, copiar/mover/papelera/restaurar, conflictos, miniaturas; 35 pruebas unittest |
| `python3 bar/tests/files-settings.py` | defaults, validación y ida y vuelta de la sección `files` |
| `python3 bar/tests/files-ipc.py` | IPC `files open|toggle|close` con `bar/files-test-host.qml` aislado |
| `python3 bar/tests/files-performance.py` | 20000 archivos offscreen: apertura en frío, scroll (p50/p95), navegación, RSS, perfil por tipo; escribe JSON en /tmp. Medida, no QA visual |

Offscreen no es QA visual ni de Wayland: arrastre real, DnD saliente, multimonitor, apertura en frío vía `FilesWindow`
y windowrules de Hyprland quedan para QA manual.

