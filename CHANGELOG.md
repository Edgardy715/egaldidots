# Changelog

## 2026-09-28 — Controls, authorization, lockscreen and Starship

- Shared interaction feedback across Isla: fixed hit targets, keyboard focus,
  bounded spring return, reduced motion and finite Lucide icon animations.
- AuthPrompt shared by sudo/Polkit presentation, with masked input, immediate
  retry, account selection, cancellation and retained success feedback.
  The Fish Stow package includes the sudo askpass helper and option-preserving
  wrapper; reloads hand off the socket instead of deleting its replacement.
- Repository lockscreen with wallpaper blur, profile/avatar, media, guarded PAM
  input and pill-to-card/return choreography. Its installer backs up the prior
  launcher; hyprlock remains available as a failure fallback.
- Session menu refreshed with a profile header and four action cards. New
  settings: `profile.displayName` and `paths.userAvatar`.
- Fish now uses Starship with the 🎩 signature, Git/development context and
  transient history. Its colors follow pywal with contrast adjustment.
- Bootstrap dependencies, source packages, licenses, documentation and safe
  regression fixtures updated. Qt >= 6.10 is required for icon path trimming.

Publication validation: 24 core checks and Wayland fixtures for icons,
AuthPrompt and lockscreen motion passed. The repository askpass bridge and
launcher installer also pass with fake credentials/processes and temporary
paths. Visual captures were inspected; they do not measure every frame or
full-shell GPU performance. Multi-monitor lockscreen behavior and extended use
remain to be verified. Publication tests never lock, authenticate or run power
actions against the real session.

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
