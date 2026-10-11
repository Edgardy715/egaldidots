# Edots

Edots is Isla's settings panel. Open or close it with Super + I, or run
`bar/settings/open.sh` while Isla is running. To install a desktop launcher,
run `bar/settings/install.sh`.

## Settings

The pages cover appearance, workspace styles, optional bar modules, fonts,
motion, profile and file paths. Search filters the available settings.
The bar supports split and compact layouts.

Changes preview in the running shell. **Save** writes them to
`~/.config/isla/shell.json`; **Discard** restores the values from disk.
Closing the panel keeps the current page and unsaved edits.

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
