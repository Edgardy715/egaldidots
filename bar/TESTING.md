# Tests

Run commands from the repository root. Python tests that write configuration
use temporary directories; do not point test fixtures at your personal settings.

## Configuration and data

```sh
sh bar/tests/verify-config.sh
node bar/tests/media-source.cjs
node bar/tests/lyrics.cjs
python bar/tests/settings-integration.py
python starship/.config/starship/test_pywal.py
```

The configuration gate includes settings validation, component boundaries and
the calculator parser. The integration test runs the QML settings service and
checks IPC, reloads, conflicts and atomic saves.

## Installer and authentication

```sh
python scripts/test-install.py
python bar/tests/lockscreen-launcher.py
python bar/tests/auth-backend.py
python bar/tests/auth-bridge.py
python bar/tests/auth-transport.py
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

Use Wayland for fixtures involving layer surfaces, focus or native keyboard
input. Some fixtures need a driver script or simulated service; check their
setup before running them directly.

```sh
python bar/tests/settings-surface-switch.py
python bar/tests/settings-media-routing.py
python bar/tests/settings-ux.py
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
