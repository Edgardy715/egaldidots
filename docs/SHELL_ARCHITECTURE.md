# Shell architecture

Isla is a Quickshell shell. `bar/shell.qml` starts the runtime, exposes IPC and
creates an overlay and reserved area for each monitor.

## Main components

| Component | Role |
| --- | --- |
| `Singletons/Settings.js` | Defaults, field metadata, validation and patch merging |
| `Singletons/Config.qml` | Settings file, drafts, reload, save and settings IPC |
| `Singletons/HyprlandSettings.qml` | Compositor preview, separate persistence and runtime recovery |
| `Singletons/Flags.qml` | Read-only compatibility bindings to Config |
| `Singletons/Theme.qml`, `Motion.qml` | Appearance and motion tokens |
| `components/ShellRuntime.qml` | Service initialization and shell integration |
| `components/SurfaceRouter.qml` | Active monitor, panel navigation and pending transitions |
| `windows/IslandOverlay.qml` | Per-monitor composition, focus and input masks |
| `windows/IslandReserve.qml` | Space reserved at the top of the screen |
| `Pill.qml` | Main bar, panel host and header composition |
| `settings/` | Edots settings editor and controls |
| `fluid/` | Droplet geometry, springs and rendering |

`surfaces/` connects desktop services to views in `components/`. Views receive
data through properties and request actions through signals. Connect Players,
Cava, Hyprland and other services in the composition layer, rather than in leaf
visual components. `MediaSession.qml` handles a view's media state and actions;
it does not replace the global Players service.

`PillGeometry.qml` and `IslandGeometry.qml` provide shared geometry.
`PillMorphMotion.qml` controls the bar's morph; `PillHeaderView.qml` presents its
header. `OverlayInputPolicy.qml` owns focus and input decisions. Keep navigation
state in SurfaceRouter rather than duplicating it in each window.

Optional modules are composed by `TopBarModules.qml` and `OptionalModule.qml`.
The main pill is required; disabled modules release input and unload after their
exit transition. Both split and compact layouts use the same settings and data.

## Configuration

The file is `$ISLA_CONFIG`, or `$XDG_CONFIG_HOME/isla/shell.json` with a fallback
to `$HOME/.config/isla/shell.json`. See `bar/shell.json.example`.

- Format version is 1; legacy files without a version are accepted.
- Missing fields use defaults. Unknown keys are preserved when saving.
- Invalid types, ranges, non-finite numbers, relative paths and unsupported
  versions reject the whole document.
- Paths accept absolute paths, `~` and `~/...`; defaults respect XDG directories.
- Invalid data at startup uses defaults; later failures retain the last valid state.

Change settings with `Config.update`, `Config.discard` and `Config.save`.
Flags is read-only. Pass settings to visual components through properties.
The Hyprland page uses a separate controller and `isla/hyprland.json`: compositor
values come from the live session rather than shell defaults. Its bounded Python
bridge validates Lua arguments and applies selected options without reload.
ShellRuntime initializes saved overrides; views receive the controller by property.
Profile name and avatar affect presentation, not the PAM account.
The independent lockscreen reads persisted settings, not the bar's live preview.

## IPC

With Isla running:

```sh
quickshell -c bar ipc call settings schema
quickshell -c bar ipc call settings catalog
quickshell -c bar ipc call settings get
quickshell -c bar ipc call settings validate '{"appearance":{"fontScale":1.1}}'
quickshell -c bar ipc call settings update '{"appearance":{"fontScale":1.1}}'
quickshell -c bar ipc call settings discard
quickshell -c bar ipc call settings save
quickshell -c bar ipc call settings reload
```

`schema` describes fields and defaults; it is not JSON Schema. `catalog` includes
modules, panels and declared dependencies, rather than live device availability.
`get` reports the document, effective values, dirty/saving state and errors.
`validate` checks a complete document without applying it. `update` merges and
validates a patch for live preview; `discard` restores disk values.

`save` accepts an asynchronous request. Check `saving`, `error` and `dirty` to
confirm completion. A failed write retains the previous file and in-memory edits.
Read or validation errors block saving until corrected and reloaded.

Save rereads the file to detect external edits, but does not lock out other
writers between that check and the atomic rename. Use Config as the editor's
writer, and reload after manual edits. Edots also detects changes to a field
while its draft is being edited.

## Adding a setting or panel

1. Define the field, default and limits in Settings.js.
2. Add validation cases and update the example configuration.
3. Connect the value in composition, exposing a read-only binding if needed.
4. Pass data and actions to the view through properties and signals.
5. For a panel, register its route, geometry and catalog entry.
6. Run the [configuration gate and relevant tests](../bar/TESTING.md).

Test persistence with a temporary `ISLA_CONFIG`. Check focus, rapid panel swaps,
reduced motion and both bar layouts when changing presentation.

## Wallpaper color pipeline

Matugen is the sole wallpaper palette generator. `matugen/.config/matugen/generate.py` renders native templates into a staged generation and publishes by swapping `~/.cache/matugen/current`; the versioned canonical document is `palette.json`. `Config.paletteFile` points to it. IslaPalette validates all required semantic roles before replacing the last valid palette; Theme composes the roles with existing glass/motion. Primary controls use primaryContent and containers use their corresponding content role. ANSI/Base16 belongs to terminal consumers, not UI role selection.

The shared wallpaper applicator calls the same pipeline for picker and startup. Live palette reload uses `island.reloadColors`, since a watcher may retain the old symlink target. GTK processes may need reopening to reload their CSS provider.

## Media image presentation

`ArtworkImage` retains two decoded images and serializes each crossfade while
coalescing pending URLs. The expanded media composition owns its clock: `Pill`
for compact layout and `FluidMediaCompanion` for split. It preloads panel and
ambient decode sizes before starting. `PillMaterial` and the surface view receive
that owner through `artworkTransition`; `PillSurfaceHost` forwards it on load.
Keep the owner alive through the displayed surface's outgoing transition, then
release its URLs. Compact covers can use the same component independently.

`CrossfadeLabel` is limited to discrete media metadata; continuously updated
numbers remain Text. The expanded title reserves two complete font lines to
prevent layout jumps and clipping. Theme/Matugen and Motion remain the owners of
colors and durations. Appearance exposes materialDepth, mediaTransitions and
menuSelectionAnchor through the normal Config draft/save/discard path.

## Performance and service lifetime

MediaSurface passes its stable MediaSession QObject to MediaView; presentation
fields notify independently rather than replacing a JS snapshot on position ticks.
CAVA consumers follow effective visibility, and its shared envelope sleeps at
exact silence. Stream discovery listens to Pulse events with bounded retries and
reconciliation; only owning-client changes can invalidate stream identity.
DesktopStatus follows native default-device/audio notifications without a rebind
timer.

WallpaperScanner.startScan returns before enumeration and metadata checks finish.
Consumers must use scanDone/scanFinished. One job per scanner runs in the existing
QtConcurrent pool; later requests replace the pending request and stale results
are discarded. Result conversion to QML still runs on the UI thread.

Nmcli's read-only monitor starts through nmcli_monitor.py, which arms Linux
parent-death cleanup and execs nmcli. No Python supervisor remains. Commands that
mutate network state keep their existing lifecycle. The installer builds the same
Wpscan module against local Qt.

The shell is hybrid: QML/Qt owns presentation, bindings and animation; the optional
Rust `rust/cava-stream` helper owns CAVA discovery/capture orchestration. Native
CAVA still computes the spectrum and parec captures the selected stream. The
exec launcher `bar/services/cava-stream.sh` chooses the installed native helper
and passes Quickshell's PID, or uses Python when the binary is unavailable.
Both preserve the same 24-band protocol and exact stream/monitor selection.
No new daemon starts at shell startup; the helper runs only for CAVA consumers.
`sh scripts/build-cava-helper.sh` performs a locked release build and atomically
installs into XDG_DATA_HOME/isla/bin; cargo is optional at install time and never
needed at runtime. Removing that binary restores Python on the next capture.
Measured evidence and limits: `docs/rust-cava-2026-10-21/REPORT.md`.

AudioController retains the Python audio bridge and time-based peak envelope.
`audio_meter.py` optionally loads `isla/lib/libisla_audio_peak.so` from
XDG_DATA_HOME (default `~/.local/share`), reducing finite float32 samples in
process via a versioned C ABI. Capture, routing, fragmented PCM handling and
JSON publication stay in Python; there is no new process or daemon. A missing
or unloadable library/symbol uses the Python reducer. The owned array remains
alive throughout the synchronous FFI call. `sh scripts/build-audio-peak.sh`
builds the dependency-free release with Cargo.lock and installs atomically.
New bridges load the replacement; removing the library restores fallback on
the next bridge start. Evidence: `docs/rust-audio-peak-2026-10-21/REPORT.md`.

Audio bridge children also use `process_lifetime.die_with_parent` before exec,
capturing the expected owner before fork. The same lightweight Linux guard is
shared with CAVA's Python fallback and the Nmcli launcher. This covers forced
bridge termination where Python finally cannot run; normal EOF/TERM cleanup
still waits and reaps. These Python launchers remain single-threaded.

Saved clipboard reads use the exec launcher `services/clipboard-list.sh`.
The optional `isla-clipboard-list` binary validates and lists metadata under the
same private permissions and exclusive flock as Python. It checks snapshot
existence/type without reading their payloads. ClipboardController selects it
only for `list`; all writes, previews, copies and history commands retain the
existing services. No watcher or daemon is added. JSON parser compatibility
cases exec the Python reader after releasing the lock; missing binary also uses
Python. `scripts/build-clipboard-list.sh` builds locked and installs atomically
under XDG_DATA_HOME/isla/bin. Removing the binary restores Python on the next
list request. Measurements: `docs/rust-clipboard-list-2026-10-21/REPORT.md`.
