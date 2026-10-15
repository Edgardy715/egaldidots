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
