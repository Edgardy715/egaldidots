# Desktop recovery

The supported starting point is an installed Arch/CachyOS system with working
GPU drivers, internet, Git, a normal user and sudo access. Run `./install.sh`
as that user. Installation modifies system packages, enables NetworkManager
and user audio services, and changes the user's shell to Fish unless
`--keep-shell` is supplied. Review the package list on systems with other audio
or network stacks before running it.

The installer restores tracked configuration and required runtime assets. It
does not repartition disks, install the OS, configure GPU drivers, install a
display manager, restore personal data or credentials, or install optional
GRUB/SDDM themes. Install those separately as appropriate. Changes that never
reached GitHub cannot be recovered from this repository.

Default monitor settings enable connected displays at their preferred modes.
The original dock profile is available with `--hardware-profile original`;
it disables the internal laptop panel and assumes the original NVIDIA hardware.
Custom overrides live outside the checkout in
`~/.config/hypr/local.hardware.conf`.

Conflicting tracked files are moved to a unique `~/.egaldidots-backup-*`
directory. Unrelated files remain. Foreign directory symlinks are rejected
before configuration changes. Earlier Stow directory links are unfolded safely.
Repeating installation rebuilds generated assets and preserves local hardware
overrides. On failure, fix the reported error and rerun; changes already made
are not automatically rolled back. Keep the checkout in place.

After logging into Hyprland, run `./install.sh --check`. It checks dependencies,
the wallpaper palette, Fish and locked Neovim plugins, the Wpscan QML import,
fonts, enabled services, Hyprland configuration errors, Isla IPC and Polkit
registration. Outside a Hyprland session the last three checks are deferred.
An enabled service check does not confirm device-level operation: test audio,
Wi-Fi, wallpaper selection, screenshot and Super+L interactively after login.

## Automated checks

```sh
python3 scripts/test-install.py
python3 bar/tests/lockscreen-launcher.py
```

Install Python, GNU Stow and ripgrep before running these checks.

The recovery suite uses real GNU Stow in temporary home directories, including
paths with spaces and legacy folded links. Package managers, desktop processes,
downloads, Qt compilation, Neovim and service operations are simulated. These
tests establish installer control flow, backup behavior and failure propagation;
they do not establish that current Arch/AUR packages build successfully or that
the desktop renders on physical hardware. Full end-to-end validation requires
a clean Arch/CachyOS VM and a graphical session.
