# Tests

Run commands from the repository root. Python tests that write configuration
use temporary directories; do not point test fixtures at your personal settings.

## Configuration and data

```sh
sh bar/tests/verify-config.sh
node bar/tests/media-source.cjs
node bar/tests/lyrics.cjs
python bar/tests/settings-integration.py
python bar/tests/hyprland-settings.py
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

The Cava envelope and discovery tests use synthetic data and fake producers;
they never capture personal audio. `nmcli-lifetime.py` checks graceful quit,
SIGTERM, hot reload and monitor restart using fake NetworkManager commands.
`desktop-status-audio-rebind-regression.qml` tests observer replacement with
mock devices. The native scanner test checks stale scans, coalescing, reentry
and destruction while work is active.

`wallpaper-scan-benchmark.py --build /tmp/isla-wpscan-test` measures call latency,
completion and a QML heartbeat with temporary caches. `sample-process.py --pid
PID --seconds 30 --output /tmp/process.json` reads Linux CPU/RSS/PSS. For a real
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

Use Wayland for fixtures involving layer surfaces, focus or native keyboard
input. Some fixtures need a driver script or simulated service; check their
setup before running them directly.

```sh
python bar/tests/settings-surface-switch.py
python bar/tests/settings-media-routing.py
python bar/tests/settings-ux.py
python bar/tests/hyprland-settings-ui.py
python bar/tests/overlay-native-input.py
```

These tests need a running Wayland session. Offscreen checks do not establish
visual quality or compositor input behavior.

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

`personality-regression.qml` covers finite material reception, surface result routing,
charging presentation, companion opt-out, reduced motion and hiding. Run on Wayland
with a temporary `ISLA_CONFIG`; `ISLA_TEST_OUTPUT` stores mock-only captures.
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
