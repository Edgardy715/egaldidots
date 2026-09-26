# Changelog

## 2026-09-26 — Fluid Island

### Shell and interaction

- Shared droplet engine with spring motion, Bézier bridges, interrupted
  transitions that retain velocity, and reduced-motion support.
- Right media droplet with cover art, playback visualization, metadata on hover
  and an expanding media card; absorption returns it to the clock pill.
- Temporary left session droplet with confirmation and keyboard navigation.
  The clock remains visible and media stays on the right.
- Shared media summaries in launcher, wallpaper picker and overview; revised
  wallpaper previews and compact workspace navigation.
- Notification choreography extracted from the pill, including restoration of
  the surface suspended by a popup.

### Architecture and configuration

- Reusable media presentation components, a separate media session model,
  shared island geometry, surface routing and per-monitor window adapters.
- Validated, versioned settings in `~/.config/isla/shell.json`, with an
  `ISLA_CONFIG` override and a distributable `bar/shell.json.example`.
- Settings IPC for schema, validation, preview, discard, reload and asynchronous
  atomic save. Invalid edits retain the last valid state; unknown keys survive.
- Updated architecture, motion documentation, demo instructions and regression
  checklist. Existing dotfiles and shell IPC entry points remain available.

### Validation and limits

Publication checks passed: all 12 QML regression fixtures, static configuration
checks, settings validation, settings IPC integration and media-source classification.
See [bar/TESTING.md](bar/TESTING.md) for commands and manual scenarios.
Offscreen regressions validate state and geometry, not the perceived motion,
Wayland input masks or physical key combinations. The left session gesture still
needs user acceptance. Power actions are tested with fake handlers only.
The README screenshots predate this update and do not show every new feature.
