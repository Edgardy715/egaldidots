#!/usr/bin/env bash
# Restore a desktop on an installed Arch/CachyOS system as the normal user.
set -Eeuo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPS=1; CONFIG=1; VERIFY_ONLY=0; PROFILE=portable; PROFILE_SET=0
WALLPAPER=''; CHANGE_SHELL=1
usage() {
    cat <<'EOF'
Usage: ./install.sh [options]
  --stow-only                 Restore config; dependencies must already exist
  --deps-only                 Install dependencies only
  --check                     Verify an existing installation without changing it
  --wallpaper FILE            Initial wallpaper (defaults to previous/bundled)
  --hardware-profile portable|original
                              Auto monitors/GPU (default), or original NVIDIA/dock
  --keep-shell                Keep the current login shell
  --help                      Show this help
Run as your normal user. sudo is used only for system operations.
Requires an installed Arch/CachyOS system, internet, sudo and working GPU drivers.
EOF
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
trap 'printf "Installation failed at line %s. Fix the error and rerun. Backup: %s\n" "$LINENO" "${BACKUP:-not created}" >&2' ERR
while (( $# )); do
    case "$1" in
        --stow-only) DEPS=0 ;;
        --deps-only) CONFIG=0 ;;
        --check) VERIFY_ONLY=1; DEPS=0; CONFIG=0 ;;
        --keep-shell) CHANGE_SHELL=0 ;;
        --wallpaper|--hardware-profile)
            (( $# >= 2 )) || die "$1 needs a value"
            if [[ "$1" == --wallpaper ]]; then WALLPAPER="$2"; else PROFILE="$2"; PROFILE_SET=1; fi
            shift ;;
        -h|--help) usage; exit 0 ;;
        --no-backup|--force) die "$1 was removed: recovery requires backups and an Arch-based system" ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done
[[ "$PROFILE" == portable || "$PROFILE" == original ]] || die "Unknown hardware profile: $PROFILE"
(( VERIFY_ONLY || DEPS || CONFIG )) || die "--deps-only and --stow-only cannot be combined"
(( EUID != 0 )) || die "Run as your normal user, not with sudo ./install.sh"
[[ -z "${XDG_CONFIG_HOME:-}" || "$XDG_CONFIG_HOME" == "$HOME/.config" ]] || die 'These dotfiles require XDG_CONFIG_HOME=$HOME/.config'
[[ -z "${XDG_CACHE_HOME:-}" || "$XDG_CACHE_HOME" == "$HOME/.cache" ]] || die 'These dotfiles require XDG_CACHE_HOME=$HOME/.cache'
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ "$DATA" == "$HOME/"* && "$STATE" == "$HOME/"* ]] || die "XDG data/state paths must be inside HOME"
[[ -r /etc/os-release ]] || die "Cannot detect OS"
# shellcheck disable=SC1091
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in *' arch '*|*' cachyos '*) ;; *) die "Requires Arch/CachyOS; detected ${ID:-unknown}" ;; esac
PKGS=(hypr kitty fish starship fastfetch nvim micro bat matugen gtk thunar git wallpapers)
for pkg in "${PKGS[@]}"; do [[ -d "$REPO/$pkg" ]] || die "Incomplete checkout: missing $pkg"; done
COMMANDS=(Hyprland hyprctl hypridle hyprlock quickshell qs fish starship python3 kitty nvim micro fastfetch bat eza zoxide fzf fd rg lazygit jq playerctl wl-copy wl-paste cliphist wl-clip-persist brightnessctl powerprofilesctl hyprshot notify-send pavucontrol thunar magick awww matugen stow cmake curl nmcli wpctl pactl cava gsettings fc-cache fc-match flock gh shfmt node npm)
PACKAGES=(hyprland hypridle hyprlock quickshell fish starship python kitty neovim micro fastfetch bat eza zoxide fzf fd ripgrep lazygit github-cli jq playerctl wl-clipboard cliphist wl-clip-persist brightnessctl hyprshot libnotify gnome-keyring pavucontrol thunar imagemagick awww ttf-jetbrains-mono-nerd ttf-google-sans-flex stow matugen networkmanager power-profiles-daemon upower dbus adwaita-icon-theme pipewire pipewire-alsa pipewire-pulse wireplumber cava polkit xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6ct qt6-base qt6-declarative qt6-svg qt6-wayland cmake ninja base-devel git curl util-linux gtk-engine-murrine gdk-pixbuf2 ruff shfmt nodejs npm unzip tree-sitter-cli)

install_deps() {
    command -v sudo >/dev/null || die "Install sudo and grant this user sudo access first"
    sudo -v
    step "Upgrade system and install dependencies"
    sudo pacman -Syu --needed --noconfirm
    local pkg helper='' tmp
    local -a official=() aur=()
    for pkg in "${PACKAGES[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then official+=("$pkg"); else aur+=("$pkg"); fi
    done
    (( ${#official[@]} == 0 )) || sudo pacman -S --needed --noconfirm "${official[@]}"
    if (( ${#aur[@]} )); then
        if command -v yay >/dev/null; then helper=yay
        elif command -v paru >/dev/null; then helper=paru
        else
            step "Build yay as the normal user"
            tmp="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
            (cd "$tmp/yay" && makepkg -si --needed --noconfirm)
            rm -rf -- "$tmp"
            helper=yay
        fi
        "$helper" -S --needed --noconfirm "${aur[@]}"
    fi
}
require_commands() {
    local cmd
    local -a missing=()
    for cmd in "${COMMANDS[@]}"; do command -v "$cmd" >/dev/null || missing+=("$cmd"); done
    (( ${#missing[@]} == 0 )) || die "Missing commands: ${missing[*]}"
    [[ -r /etc/pam.d/hyprlock ]] || die "Missing hyprlock PAM service"
}
backup_target() {
    local target="$1" rel
    [[ -e "$target" || -L "$target" ]] || return 0
    [[ "$target" == "$HOME/"* ]] || die "Backup target outside HOME: $target"
    rel="${target#"$HOME/"}"
    mkdir -p -- "$BACKUP/$(dirname -- "$rel")"
    [[ ! -e "$BACKUP/$rel" && ! -L "$BACKUP/$rel" ]] || die "Duplicate backup target: $rel"
    mv -- "$target" "$BACKUP/$rel"
}
write_generated() {
    local target="$1" temp
    [[ "$target" == "$HOME/"* ]] || die "Generated target outside HOME: $target"
    if [[ -L "$target" || ( -e "$target" && ! -f "$target" ) ]]; then backup_target "$target"; fi
    mkdir -p -- "$(dirname -- "$target")"
    temp="$(mktemp "$(dirname -- "$target")/.egaldidots.XXXXXX")"
    cat > "$temp"
    if [[ -f "$target" ]] && cmp -s "$temp" "$target"; then rm -- "$temp"; return 0; fi
    backup_target "$target"
    mv -- "$temp" "$target"
}
install_config() {
    step "Backup and link dotfiles"
    BACKUP="$(mktemp -d "$HOME/.egaldidots-backup-$(date +%Y%m%d-%H%M%S).XXXXXX")"
    python3 "$REPO/scripts/prepare-stow.py" "$REPO" "$HOME" "$BACKUP" "${PKGS[@]}"
    mkdir -p -- "$STATE"
    stow --simulate --no-folding -R -d "$REPO" -t "$HOME" "${PKGS[@]}"
    stow --no-folding -R -d "$REPO" -t "$HOME" "${PKGS[@]}"
    local bar="$HOME/.config/quickshell/bar"
    if [[ "$(readlink -f -- "$bar")" != "$REPO/bar" ]]; then
        backup_target "$bar"
        mkdir -p -- "$(dirname -- "$bar")"
        ln -s -- "$REPO/bar" "$bar"
    fi
    local hardware="$HOME/.config/hypr/local.hardware.conf"
    if [[ ! -e "$hardware" || "$PROFILE_SET" == 1 ]]; then
        if [[ "$PROFILE" == original ]]; then
            write_generated "$hardware" < "$REPO/profiles/original.hardware.conf"
        else
            printf '# Portable defaults. Add machine-specific monitor/GPU settings here.\n' | write_generated "$hardware"
        fi
    fi
    bash "$REPO/bar/lockscreen/install.sh"
    post_fisher
    install_gtk
    build_plugin
    seed_palette
    post_neovim
    bat cache --build
    fc-cache -f
    step "Enable desktop services for the next login"
    sudo systemctl enable NetworkManager.service
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
    if (( CHANGE_SHELL )); then
        sudo chsh -s "$(command -v fish)" "$(id -un)"
    fi
}
post_fisher() {
    step "Install Fish plugins"
    local temp plugins="$HOME/.config/fish/fish_plugins"
    # Fisher rewrites its manifest. Keep generated state out of the checkout.
    if [[ -L "$plugins" ]]; then
        temp="$(mktemp)"
        cp -L -- "$plugins" "$temp"
        rm -- "$plugins"
        mv -- "$temp" "$plugins"
    fi
    temp="$(mktemp)"
    curl --fail --location --retry 3 https://raw.githubusercontent.com/jorgebucaran/fisher/4.4.5/functions/fisher.fish -o "$temp"
    fish --no-config -c 'source $argv[1]; fisher install jorgebucaran/fisher patrickf1/fzf.fish' "$temp"
    rm -- "$temp"
}
post_neovim() {
    step "Restore Neovim plugins from lazy-lock.json"
    local lock="$HOME/.config/nvim/lazy-lock.json" lazy="$DATA/nvim/lazy/lazy.nvim" commit
    # Lazy writes its lockfile: detach the Stow link before invoking it.
    if [[ -L "$lock" ]]; then
        rm -- "$lock"
        cp -- "$REPO/nvim/.config/nvim/lazy-lock.json" "$lock"
    fi
    commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["lazy.nvim"]["commit"])' "$REPO/nvim/.config/nvim/lazy-lock.json")"
    if [[ ! -d "$lazy/.git" ]]; then
        [[ ! -e "$lazy" ]] || backup_target "$lazy"
        mkdir -p -- "$(dirname -- "$lazy")"
        git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$lazy"
    fi
    git -C "$lazy" fetch origin "$commit"
    git -C "$lazy" checkout --detach "$commit"
    timeout 600 nvim --headless '+Lazy! install' '+qa'
    cp -- "$REPO/nvim/.config/nvim/lazy-lock.json" "$lock"
    timeout 600 nvim --headless '+Lazy! restore' '+qa'
    timeout 60 nvim --headless -l "$REPO/scripts/verify-nvim.lua"
}
install_gtk() {
    step "Use Adwaita with Matugen GTK roles"
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita
}

build_plugin() {
    step "Build Wpscan against the installed Qt"
    local build
    build="$(mktemp -d)"
    cmake -S "$REPO/wpscan" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build "$build" --parallel 2
    mkdir -p -- "$DATA/isla/qml"
    [[ ! -e "$DATA/isla/qml/Wpscan" && ! -L "$DATA/isla/qml/Wpscan" ]] || backup_target "$DATA/isla/qml/Wpscan"
    cp -a -- "$build/Wpscan" "$DATA/isla/qml/Wpscan"
    rm -rf -- "$build"
}
seed_palette() {
    step "Generate initial wallpaper palette"
    local wall="$WALLPAPER"
    if [[ -z "$wall" && -f "$HOME/.cache/matugen/wallpaper.txt" ]]; then wall="$(cat "$HOME/.cache/matugen/wallpaper.txt")"; fi
    if [[ -z "$wall" || ! -f "$wall" ]]; then
        [[ -z "$WALLPAPER" ]] || die "Wallpaper not found: $WALLPAPER"
        wall="$(find -L "$HOME/Wallpapers" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit)"
    fi
    [[ -n "$wall" && -f "$wall" ]] || die "No wallpaper in checkout; use --wallpaper FILE"
    bash "$HOME/.config/hypr/scripts/apply-wallpaper.sh" --seed "$wall"
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita
}
verify() {
    step "Verify desktop prerequisites"
    require_commands
    [[ "$(readlink -f -- "$HOME/.config/quickshell/bar")" == "$REPO/bar" && -f "$HOME/.config/quickshell/bar/shell.qml" ]] || die "Isla configuration not installed"
    [[ -s "$DATA/isla/qml/Wpscan/qmldir" ]] || die "Wpscan plugin missing"
    [[ -x "$DATA/quickshell-lockscreen/lock.sh" ]] || die "Lockscreen launcher missing"
    [[ -x "$HOME/.local/bin/isla" && -x "$HOME/.local/bin/isla-sudo-askpass" ]] || die "Isla launchers missing"
    python3 -c 'import json,os; p=json.load(open(os.path.expanduser("~/.cache/matugen/palette.json"))); assert p["generator"] == "matugen" and p["version"] == 1 and "on_primary" in p["colors"]'
    [[ -s "$HOME/.cache/matugen/outputs/colors-hyprlock.conf" ]] || die "Lockscreen palette missing"
    [[ -s "$HOME/.cache/matugen/outputs/colors.css" ]] || die "Matugen GTK palette missing"
    [[ "$(fc-match -f '%{family}' 'Google Sans Flex')" == *'Google Sans Flex'* ]] || die "Google Sans Flex font missing"
    fish --no-config -c 'source ~/.config/fish/functions/fisher.fish; type -q fisher; and test -f ~/.config/fish/functions/fzf_configure_bindings.fish' || die "Fish plugins missing"
    QML_IMPORT_PATH="$DATA/isla/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" QT_QPA_PLATFORM=offscreen \
        timeout 15 quickshell -p "$REPO/scripts/plugin-check.qml"
    systemctl is-enabled --quiet NetworkManager.service || die "NetworkManager not enabled"
    systemctl --user is-enabled --quiet pipewire.socket pipewire-pulse.socket wireplumber.service || die "Audio services not enabled"
    timeout 60 nvim --headless -l "$REPO/scripts/verify-nvim.lua"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        local errors auth
        errors="$(hyprctl configerrors)"
        [[ -z "$errors" || "$errors" == 'ok' ]] || die "Hyprland config errors: $errors"
        timeout 10 "$HOME/.local/bin/isla" ipc call settings get >/dev/null
        auth="$(timeout 10 "$HOME/.local/bin/isla" ipc call authDebug status)"
        [[ "$auth" == *'registered=true'* ]] || die "Isla Polkit agent not registered"
    fi
}
if (( VERIFY_ONLY )); then verify; printf '\nInstallation checks passed.\n'; exit 0; fi
if (( DEPS )); then install_deps; fi
require_commands
if (( CONFIG )); then install_config; verify; fi
printf '\nCompleted successfully. Backup: %s\n' "${BACKUP:-no config changes}"
if (( CONFIG )); then printf 'Log out and select Hyprland. Run ./install.sh --check after login.\n'; fi
