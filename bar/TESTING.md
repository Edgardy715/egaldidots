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
python starship/.config/starship/test_matugen.py
```

The configuration gate includes settings validation, component boundaries and
the calculator parser. The integration test runs the QML settings service and
checks IPC, reloads, conflicts and atomic saves.

## Installer and authentication

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

## Manual checks

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
