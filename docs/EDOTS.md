# Edots

Edots is Isla's settings panel. Open or close it with Super + I, or run
`bar/settings/open.sh` while Isla is running. To install a desktop launcher,
run `bar/settings/install.sh`.

## Settings

The pages cover appearance, workspace styles, optional bar modules, fonts,
motion, profile, file paths and Hyprland. Search filters settings and links to
the compositor page for flow and animation queries.
The bar supports split and compact layouts.

Changes preview in the running shell. **Save** writes them to
`~/.config/isla/shell.json`; **Discard** restores the values from disk.
Closing the panel keeps the current page and unsaved edits.

## Hyprland

The Hyprland page reads the running compositor's layout and animations. Choose
scrolling columns, dwindle tiling or master layout, and adjust the enabled state,
style and duration of window opening, window closing and workspace transitions.
Changes preview in the current session through the Lua runtime API; the panel
does not reload Hyprland or edit its configuration modules.

This page has its own **Save** and **Revert** controls. Save writes
`$XDG_CONFIG_HOME/isla/hyprland.json` (normally `~/.config/isla/hyprland.json`);
Isla restores these overrides when it starts. Revert restores the values read
when the page initialized, or the last saved values. Closing the panel retains
the preview. Saving shell appearance uses the separate `shell.json` file.

The first version supports Hyprland 0.56's Lua API. It preserves animation
curves and does not expose inherited leaves that cannot be restored precisely
without a compositor reload. Physical spring curves determine their own
duration. Explicit workspace child animations can override the parent setting,
and globally disabled animations remain disabled.

**Refresh** rereads the runtime when no preview is pending. File conflicts block
saving. An invalid saved file remains intact until **Use current session** is
chosen; that action creates a backup before replacing it with the live settings.
`ISLA_HYPRLAND_CONFIG` selects an isolated persistence file for tests.

Numeric fields validate their ranges before applying an edit. If the same field
changes on disk while you are editing it, resolve the conflict by editing,
resetting or discarding the draft before saving.

## Files and folders

Path fields accept an absolute path, `~` or `~/...`. The picker supports images,
JSON files, scripts and folders as appropriate. Select a file, then confirm;
Escape cancels the picker without changing the setting.

Avatar and display name affect the interface only; they do not change the system
account used for authentication.

## Manual configuration

Start with `bar/shell.json.example`. Missing values use defaults, and unknown
keys are preserved when saving. Invalid documents leave the last valid settings
active. `ISLA_CONFIG` selects a different file for development and tests.

See [the settings API](SHELL_ARCHITECTURE.md) for IPC and validation details.
