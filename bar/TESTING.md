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
