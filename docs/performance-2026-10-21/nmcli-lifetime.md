# Nmcli monitor: ownership on shell termination

2026-10-21. Isolated Quickshell 0.3.2 (Arch Linux), `QT_QPA_PLATFORM=offscreen`, real
`bar/Singletons/Nmcli.qml`, fake `nmcli` from a temporary PATH. No desktop
process was signalled or restarted. Deployment and the historical orphan are
the coordinator's responsibility.

## Cause and choice

The silent `nmcli monitor` survives SIGTERM of its Quickshell parent. Graceful
`Qt.quit()` already cleans it up; a closed stdout pipe cannot stop a monitor
that is blocked waiting for a network event.

Installed `Quickshell/Io/quickshell-io.qmltypes` has no `manageLifetime`.
`Qt.application` **does** inherit `aboutToQuit` from `QQmlApplication`
(`/usr/lib/qt6/qml/QML/plugins.qmltypes`, also `builtins.qmltypes`). The
Quickshell global exposes reload signals but no shutdown signal. A candidate
`Connections { target: Qt.application; function onAboutToQuit(): void {
monitorProc.running = false } }` was tested with the direct `nmcli` command:
it still leaves an orphan after SIGTERM, including after a hot reload.
That hook cannot cover this termination path.

`services/nmcli_monitor.py` reuses `cava_stream.die_with_parent`, then
`os.execvp` replaces the helper with `nmcli monitor`. Linux
`PR_SET_PDEATHSIG(SIGKILL)` remains armed across exec: no persistent Python
supervisor or polling. The QML command passes `Quickshell.processId`, so the
existing parent-identity check also covers death before the helper imports or
arms the signal. Death after arming is covered by the kernel. No mutation,
rescan or connection commands are wrapped; event parsing, callbacks and the
existing 2s crash restart remain unchanged.

## Reproduction and validation

`python bar/tests/nmcli-lifetime.py` uses a fake monitor blocked in
`signal.pause()` without periodic stdout. It checks refresh on a synthetic
event, restart after killing only that fake monitor, then shell shutdown. The
reload case asserts exactly one live monitor after a real
`Quickshell.reload(false)`, then terminates that isolated shell. Cleanup kills
only PIDs registered by that temporary fake.

| Source | Qt.quit | SIGTERM | Hot reload followed by SIGTERM |
| --- | --- | --- | --- |
| Before fix | PASS | RED: orphan | RED: orphan |
| Native aboutToQuit candidate | PASS | RED: orphan | RED: orphan |
| Final helper | PASS | PASS | PASS |

Final result: zero surviving fake monitors in all three modes. The test also
asserts that the fake monitor's direct parent is Quickshell (exec preserves
ownership), and that a mismatched/dead expected parent aborts before exec.

- `python bar/tests/nmcli-lifetime.py`: PASS, 3 modes plus parent-race guard.
- `python bar/tests/nmcli-service.py`: PASS; 40 refresh requests → 2 serialized
  reads, 25 completed commands → 0 objects, recovery and callback identity.
- `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml bar/Singletons/Nmcli.qml`:
  exit0; existing singleton/qmldir warning when linting the file directly.
- `git diff --check -- bar/Singletons/Nmcli.qml bar/tests/nmcli-service.py`: PASS.

Limits: no deployment or live NetworkManager mutation was performed. Offscreen
reload logs an unavailable internal reload-popup backend; the actual reload,
replacement monitor, events and process cleanup are exercised. This validates
process lifetime, not visual output or real network changes.
