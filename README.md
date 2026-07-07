<div align="center">

# egaldidots

**A wallpaper-driven, pywal-synchronized Hyprland rice for CachyOS / Arch.**
Pick one wallpaper → the bar, menus, lock screen, terminal, editor,
notifications and fetch all recolor from it in one stroke.

[![Arch](https://img.shields.io/badge/Arch-CachyOS-1793d1?logo=arch-linux&logoColor=fff)](https://cachyos.org)
[![Wayland](https://img.shields.io/badge/Wayland-Hyprland-00b3a4)](https://hyprland.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e6e6e)](./LICENSE)
[![Theming: pywal16](https://img.shields.io/badge/theming-pywal16-9b59b6)](#-how-the-theming-works)

<!-- ─────────────────────────────────────────────────────────────────────── -->
<!--  TODO: drop your screenshots here, e.g.  ./assets/screenclean.png        -->
<!--  ![clean](./assets/screenclean.png)   ![rofi](./assets/rofi.png)        -->
<!-- ─────────────────────────────────────────────────────────────────────── -->

> 📸 **Screenshots:** add them under `assets/` and uncomment the block above.

</div>

---

## 📑 Contents

- [What it is](#-what-it-is)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [How the theming works](#-how-the-theming-works)
- [Repository structure](#-repository-structure)
- [Manual (sudo) steps — not done by the installer](#-manual-sudo-steps--not-done-by-the-installer)
- [Customizing](#-customizing)
- [Credits](#-credits)
- [License](#-license)

---

## 🧭 What it is

`egaldidots` is my personal dotfiles repo, built from my **CachyOS** setup. It
is a **single-source-of-truth rice**: exactly one daemon (`pywal16`) derives a
16-color palette from the active wallpaper, and every UI surface reads from that
palette — either directly (kitty, rofi, hyprland, hyprlock, waybar, swaync,
wlogout) or through a thin adapter (Tide prompt in fish, LazyVim statusline in
neovim, fastfetch). Change the wallpaper once and the whole desktop follows in
real time, even in already-open terminals.

`install.sh` reproduces the setup on a fresh Arch / CachyOS box: it installs
the dependency list **derived from what these configs actually use** (not a
generic bootstrap), backs up any pre-existing config with a timestamp, and
symlinks every package into `$HOME` with **GNU Stow** — without ever touching
`/etc`, `/usr` or `/boot`.

---

## ✨ Features

- **Hyprland** (modular config, `source`-split into `modules/`) with
  **hypridle** idle daemon and a custom **hyprlock** lock screen — a
  glassy "dynamic-island" aesthetic with a live clock, now-playing
  (mpris), battery and user/uptime labels, all wallpaper-tinted.
- **pywal16** is the theming root. A custom wallpaper-picker script
  indexes `~/Wallpapers` by **dominant color** (via `magick`), buckets
  them across the spectrum and renders a searchable rofi menu with
  thumbnails. Select one → `awww` swaps it, pywal regenerates the
  palette, wpgtk rebuilds the GTK theme, and a `wal_sync_signal`
  universal-variable fans the recolor out to **every** surface live.
- **fish** + **Tide** (v6) with a pywal-derived **"slate" prompt theme**:
  a single cohesive bar (`color8` surface, darkened dividers), wallpaper-
  tinted pwd/branch, and fixed Catppuccin/Nord accents for semantic states
  (git staged/dirty, status ok/fail, vi modes) so they stay legible on any
  palette. Re-applied live on wallpaper change without restarting the shell.
- **kitty** with translucent blurred background, powerline tabs and pywal
  colors.
- **LazyVim** (neovim) heavily customized: pywal-synced statusline,
  satellite scrollbar, notify and dashboard (which renders the same ASCII
  hat as fastfetch), plus a network-engineering tilt (`cisco.vim`,
  `vim-fortios`), conform.nvim formatting (ruff/shfmt), navic breadcrumbs,
  mini.animate/indentscope, toggleterm.
- **waybar** ("dynamic-island" glass bar, active-workspace dot with a
  `breathe` keyframe), **rofi** (app launcher, clipboard, wallpaper-picker),
  **wlogout** (power menu) and **swaync** (notification dock) — all reading
  pywal colors.
- **fastfetch** with a custom Mario-style ASCII hat and nerd-font section
  separators.
- **micro** editor with Catppuccin color schemes; **bat** with a Catppuccin
  theme; `eza`/`zoxide`/`fzf`/`fd`/`rg` wired into fish.
- **Clipboard** persistence (`wl-clip-persist` + `cliphist`), **GNOME
  Keyring** secret store, **brightnessctl**, **hyprshot** screenshots,
  **playerctl** media control.
- A laptop docked to an external **240 Hz** monitor with **VRR**, with the
  internal panel disabled — NVIDIA-flavored env in `envVars.conf`.

---

## ✅ Requirements

- **Arch Linux or CachyOS** (or another `ID_LIKE=arch` derivative — Manjaro,
  EndeavourOS, Garuda…). `install.sh` detects this from `/etc/os-release`
  and **aborts** otherwise (override with `--force`, at your own risk).
- `pacman`; and **yay** or **paru** for the two AUR packages
  (`python-pywal16`, `wpgtk`). If neither is present the installer skips AUR
  and tells you what to run.
- **GNU Stow** is installed automatically by the installer (`extra/stow`).
- A **Wayland** session with an **NVIDIA** GPU is the intended target
  (`envVars.conf` sets `GBM_BACKEND=nvidia-drm`, `WLR_DRM_DEVICES`, etc.).
  On AMD/Intel, edit `hypr/.config/hypr/modules/envVars.conf` and drop the
  `# Nvidia` block before logging in.
- For the full look, install a Nerd Font: **JetBrainsMono Nerd Font** is in
  the dependency list (`ttf-jetbrains-mono-nerd`).

---

## 🚀 Installation

```bash
git clone https://github.com/Edgardy715/egaldidots.git ~/egaldidots
cd ~/egaldidots

# review what it will do first (it never touches /etc, /usr or /boot):
./install.sh --help

# full bootstrap: deps + timestamped backup + stow symlinks + fisher plugins
./install.sh
```

Flags:

| Flag | Effect |
| --- | --- |
| `./install.sh` | everything (default) |
| `--stow-only` | skip dependency install (everything already on the box) |
| `--deps-only` | install packages only, no symlinking |
| `--no-backup` | overwrite/push through conflicts instead of backing them up |
| `--force` | proceed even if the OS is not Arch/CachyOS |
| `--help` | show this help |

After `install.sh` finishes, **seed the palette** by picking a wallpaper:

```bash
wal -i ~/Wallpapers/<your-wallpaper>.png
# or, once you're in Hyprland, press Super+W for the dominant-color picker
```

The first `wal` run populates `~/.cache/wal/`, and every surface recolors from
it (open programs included, via `wal_sync_signal`). Then open a fish shell and
start Hyprland.

---

## 🧬 How the theming works

The rice follows a strict **source vs. generated** split. Only `source` files
live in this repo; the `generated` layer is rebuilt on the fly and is never
committed.

```
 wallpaper.png ──awww──► ~/Wallpapers (symlinked from repo)
        │
        └─► pywal16 ──┬──► ~/.cache/wal/colors.sh        (the palette: color0..15, fg, bg)
                      ├──► ~/.cache/wal/colors-kitty.conf   (custom template in repo)
                      ├──► ~/.cache/wal/colors-rofi.rasi     (custom template in repo)
                      ├──► ~/.cache/wal/colors-hyprland.conf (pywal16 built-in template)
                      ├──► ~/.cache/wal/colors-hyprlock.conf (written by generate-rofi-theme.py)
                      ├──► ~/.cache/wal/colors-waybar.css    (read by waybar/swaync/wlogout via @import)
                      └──► ~/.cache/wal/colors.fish / colors-kitty.conf …
                              │
        wpgtk ─────────────► ~/.local/share/themes/FlatColor (GTK theme, regenerated)

        fish: __wal_apply_colors() ─► Tide universal vars (colors) + fish_color_* (syntax)
              __wal_sync --on-variable wal_sync_signal ─► live recolor + repaint
        nvim: statusline/notify/satellite read ~/.cache/wal/colors
        fastfetch: colors block from pywal
```

- **Committed (source):** the configs under each package, two pywal templates
  (`wal/.config/wal/templates/colors-{kitty,rofi}`), and the Python/shell
  scripts in `hypr/.config/hypr/scripts/` that drive the picker, recolor and
  now-playing label.
- **Generated (never committed):** everything in `~/.cache/wal/`, the GTK
  `FlatColor` theme and wpgtk schemes/samples, and Tide's render caches.
- **Portability:** hardcoded home paths were removed. Hyprland/kitty use `~`
  expansion (`source = ~/.cache/...`, `include ~/.cache/...`), and GTK CSS
  files use relative `@import` (`../../.cache/wal/...`, `../../../.cache/wal/...`)
  so they resolve regardless of the username.

---

## 🗂 Repository structure

Each top-level directory is a **Stow package** that mirrors its path under
`$HOME` (so `hypr/.config/hypr/...` symlinks to `~/.config/hypr/...`).

```
egaldidots/
├── install.sh            # bootstrap (deps + backup + stow + fisher)
├── README.md  · LICENSE  · .gitignore
├── hypr/                 .config/hypr/  (hyprland.conf, modules/*.conf,
│                                        hyprlock.conf, hypridle.conf, scripts/)
├── waybar/               .config/waybar/ (config.jsonc, style.css, launch.sh)
├── rofi/                 .config/rofi/themes/  (launcher, clipboard, wallpaper-picker)
├── wlogout/             .config/wlogout/ (layout, style.css)
├── swaync/              .config/swaync/  (config.json, style.css)
├── kitty/              .config/kitty/   (kitty.conf → user.conf → pywal)
├── fish/               .config/fish/    (config.fish, fish_plugins,
│                                        conf.d/tide-structure.fish)
├── nvim/               .config/nvim/    (LazyVim: init.lua, lua/{config,plugins}/)
├── micro/              .config/micro/   (settings, catppuccin color schemes)
├── fastfetch/          .config/fastfetch/ (config.jsonc, hat.txt)
├── bat/                .config/bat/themes/ (Catppuccin Mocha)
├── wal/                .config/wal/templates/ (colors-kitty.conf, colors-rofi.rasi)
├── wpg/                .config/wpg/wpg.conf
├── gtk/                .config/{gtk-3.0,gtk-4.0}/gtk.css (filechooser bg)
├── thunar/             .config/{Thunar,xfce4}/ (custom actions, xfconf)
├── git/                .gitconfig
└── wallpapers/         Wallpapers/          (15 wallpapers, symlinked to ~/Wallpapers)
```

> **fish** notes: the Tide *structure* (which items show, separators, icons,
> padding, transient mode) is reproduced cleanly in
> `conf.d/tide-structure.fish` as universal vars — it deliberately does **not**
> commit the fisher-managed `functions/`/`completions/` (tide, fzf.fish, fisher
> regenerate those from `fish_plugins`), nor the dirty `fish_variables` cache.
> Tide *colors* are pywal-derived at runtime by `config.fish`, never pinned.

---

## 🔧 Manual (sudo) steps — not done by the installer

`install.sh` never touches system paths. What needs root is documented here
instead:

- **GRUB theme — Elegant-grub2-themes** (`vinceliuice/Elegant-grub2-themes`):

  ```bash
  git clone https://github.com/vinceliuice/Elegant-grub2-themes.git
  cd Elegant-grub2-themes
  sudo ./install.sh -t whitesur        # theme name of your choice
  # then edit /etc/default/grub:  GRUB_THEME="/boot/grub/themes/.../theme.txt"
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  ```

- **awww / pywal / wpgtk first-time setup:** these are installed by the
  installer, but the *palette* isn't seeded until you pick a wallpaper (see
  [Installation](#-installation)). No sudo needed — just `wal -i ~/Wallpapers/<file>`.

---

## 🎨 Customizing

- **Change the prompt structure** (which items, separators, icons): edit
  `fish/.config/fish/conf.d/tide-structure.fish` — it's the source of truth.
  Don't run `tide configure`; its changes would be overwritten on the next
  interactive shell.
- **Change prompt *colors*:** they're pywal-derived in `config.fish`
  (`__tide_pywal_apply`). Edit the fixed-accent block there.
- **Monitors / resolution / refresh rate:** `hypr/.config/hypr/modules/monitors.conf`.
- **GPU (non-NVIDIA):** trim the `# Nvidia` block in `hypr/.../modules/envVars.conf`.
- **Add wallpapers:** drop files into `wallpapers/Wallpapers/` (they're
  symlinked into `~/Wallpapers` by Stow, then `wal`/`awww` pick them up).

---

## 🙏 Credits

- [Hyprland](https://hyprland.org) — the compositor.
- [Tide](https://github.com/ilancosman/tide) (ilancosman) — the fish prompt.
- [fzf.fish](https://github.com/patrickf1/fzf.fish) (patrickf1) — fzf integration for fish.
- [LazyVim](https://github.com/LazyVim/LazyVim) — the neovim distribution.
- [pywal16](https://github.com/eylles/pywal16) (eylles) — the 16-color fork of pywal that powers the palette.
- [wpgtk](https://github.com/deviantfero/wpgtk) (deviantfero) — wallpaper/GTK theming manager.
- [awww](https://codeberg.org/LGFae/awww) (LGFae) — the Wayland wallpaper daemon; successor to [swww](https://github.com/LGFae/swww).
- [adi1090x/rofi](https://github.com/adi1090x/rofi) — rofi theming base my clipboard theme builds on.
- [Elegant-grub2-themes](https://github.com/vinceliuice/Elegant-grub2-themes) (vinceliuice) — GRUB theme (manual install, see above).
- [Catppuccin](https://github.com/catppuccin/catppuccin) — fixed accents & editor themes.
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) (ryanoasis) — JetBrainsMono Nerd Font for the glyphs.

---

## 📜 License

MIT © 2026 [Edgardy715](https://github.com/Edgardy715) — see [LICENSE](./LICENSE).
