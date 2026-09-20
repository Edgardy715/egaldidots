#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# install.sh · egaldidots bootstrap (Arch / CachyOS)
# ═══════════════════════════════════════════════════════════════════════════
# Installs dependencies (pacman + AUR via yay/paru), backs up any
# pre-existing config with a timestamp, and links the packages with GNU Stow
# into $HOME.
#
#   NEVER touches /etc, /usr or /boot directly: the steps that need sudo
#   for system paths (GRUB/SDDM themes) live ONLY documented in
#   README.md. Dependencies are installed via the package manager (which
#   owns those paths), not by hand.
#
#   Usage:
#     ./install.sh                 # everything: deps + backup + stow + fisher
#     ./install.sh --stow-only     # skip deps (already installed)
#     ./install.sh --deps-only     # only installs packages
#     ./install.sh --no-backup     # no backup (overwrites/conflicts)
#     ./install.sh --force         # continue even if not Arch/CachyOS
#     ./install.sh --help
#
set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
BACKUP_BASE="$HOME/.egaldidots-backup"
BACKUP_DIR="$BACKUP_BASE-$(date +%Y%m%d-%H%M%S)"

# Stow packages = each top-level repo directory is one.
STOW_PKGS=(
  hypr waybar rofi wlogout swaync kitty fish fastfetch
  nvim micro bat wal wpg gtk thunar git wallpapers
)

# Official dependencies (pacman) — derived from what the repo's
# configs/scripts REALLY use (compositor+lock+idle · bar/menus/notifs · shell
# · terminals/editors · shell utils · media/clip/brightness/screens · nerd
# fonts · stow to link · fisher, an official binary in CachyOS/extra).
PACMAN_PKGS=(
  hyprland hypridle hyprlock
  waybar rofi wlogout swaync
  fish kitty neovim micro fastfetch
  bat eza zoxide fzf fd ripgrep lazygit jq
  playerctl wl-clipboard cliphist wl-clip-persist brightnessctl hyprshot
  libnotify gnome-keyring pavucontrol thunar imagemagick
  awww fisher ttf-jetbrains-mono-nerd stow
)

# AUR dependencies (not in the official repos):
#   python-pywal16 · pywal 16-color fork, provides the `wal` command
#   wpgtk          · wallpaper/GTK manager, provides `wpg` (generates FlatColor)
AUR_PKGS=( python-pywal16 wpgtk )

# ── Colors (disabled unless a TTY) ────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_R=$'\033[0m'; C_B=$'\033[1m'; C_DIM=$'\033[2m'
  C_G=$'\033[32m'; C_Y=$'\033[33m'; C_RED=$'\033[31m'; C_BL=$'\033[34m'
else
  C_R=''; C_B=''; C_DIM=''; C_G=''; C_Y=''; C_RED=''; C_BL=''
fi
info()  { printf '%s==>%s %s\n'   "$C_BL$C_B"  "$C_R" "$*"; }
ok()    { printf '%s ✓%s %s\n'    "$C_G"        "$C_R" "$*"; }
warn()  { printf '%s ⚠%s %s\n'    "$C_Y"        "$C_R" "$*" >&2; }
err()   { printf '%s ✗%s %s\n'    "$C_RED$C_B"  "$C_R" "$*" >&2; }
die()   { err "$*"; exit 1; }
step()  { printf '\n%s── %s ──%s\n' "$C_B" "$*" "$C_R"; }

print_help() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; }

# ── Arch / CachyOS detection (warn + abort if not) ───────────────────────────
detect_os() {
  [ -r /etc/os-release ] || die "could not read /etc/os-release (not Arch?)"
  . /etc/os-release 2>/dev/null
  local id ok=""
  for id in ${ID:-} ${ID_LIKE:-}; do
    case "$id" in arch|cachyos) ok=1; break;; esac
  done
  if [ -z "$ok" ]; then
    warn "OS not detected as Arch/CachyOS — ID='${ID:-}' ID_LIKE='${ID_LIKE:-}'"
    [ "$FORCE" -eq 1 ] || die "aborting. Use --force to continue at your own risk."
    warn "--force set: continuing anyway."
  else
    ok "OS: $NAME  (ID=$ID, ID_LIKE=${ID_LIKE:-})"
  fi
}

# ── Timestamped backup of pre-existing configs, file by file ────────────────
# Moves to $BACKUP_DIR only the files the repo ALSO provides and that
# already exist in $HOME as real files (or foreign symlinks). Leaves
# everything else intact. Idempotent: symlinks already managed by this repo
# are skipped.
backup_pkg() {
  local pkg="$1"
  ( cd "$STOW_DIR/$pkg" 2>/dev/null || return 0
    find . \( -type f -o -type l \) -print0 | while IFS= read -r -d '' f; do
      rel="${f#./}"
      [ -n "$rel" ] || continue
      target="$HOME/$rel"
      { [ -e "$target" ] || [ -L "$target" ]; } || continue
      if [ -L "$target" ] && \
         [ "$(readlink -f "$target")" = "$(readlink -f "$STOW_DIR/$pkg/$rel" 2>/dev/null)" ]
      then
        continue   # already linked by this repo → left untouched
      fi
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      mv -f "$target" "$BACKUP_DIR/$rel"
      printf '   %sbackup%s  ~/%s\n' "$C_DIM" "$C_R" "$rel"
    done )
}

# ── Dependency installation ──────────────────────────────────────────────────
install_deps() {
  step "Official dependencies (pacman)"
  local pacman_bin="pacman"
  [ "$(id -u)" -eq 0 ] || pacman_bin="sudo pacman"
  $pacman_bin -Sy --noconfirm >/dev/null \
    || die "pacman -Sy failed (network? keyring? try: sudo pacman -Sy archlinux-keyring)"
  if ! $pacman_bin -S --needed --noconfirm "${PACMAN_PKGS[@]}"; then
    die "pacman failed installing: ${PACMAN_PKGS[*]}"
  fi
  ok "official dependencies OK"

  step "AUR dependencies (${AUR_PKGS[*]})"
  local helper=""
  command -v yay  >/dev/null 2>&1 && helper="yay"
  [ -z "$helper" ] && command -v paru >/dev/null 2>&1 && helper="paru"
  if [ -z "$helper" ]; then
    warn "no yay/paru found. Install one (AUR) and then:"
    warn "    ${helper:-yay} -S --needed ${AUR_PKGS[*]}"
    warn "pywal and wpgtk drive the dynamic palette of the rice — they're required."
    return 0
  fi
  if $helper -S --needed --noconfirm "${AUR_PKGS[@]}"; then
    ok "AUR dependencies OK"
  else
    warn "$helper failed on AUR — install by hand: ${AUR_PKGS[*]}"
  fi
}

# ── Linking with GNU Stow ────────────────────────────────────────────────────
enlace() {
  command -v stow >/dev/null 2>&1 \
    || die "missing \`stow\`. Install deps first: ./install.sh --deps-only"
  step "Linking ${#STOW_PKGS[@]} packages with stow → $TARGET"
  local pkg
  for pkg in "${STOW_PKGS[@]}"; do
    [ -d "$STOW_DIR/$pkg" ] || { warn "package '$pkg' missing from repo — skipping"; continue; }
    if [ "$DO_BACKUP" -eq 1 ]; then backup_pkg "$pkg"; fi
    if stow -R -d "$STOW_DIR" -t "$TARGET" "$pkg"; then
      ok "stow $pkg"
    else
      err "stow failed for '$pkg' (check for leftover conflicts in ~)"
      return 1
    fi
  done
}

# ── Post: fish plugins (tide + fzf.fish) ──────────────────────────────────────
post_fisher() {
  step "Fish plugins (fisher: tide + fzf.fish)"
  if command -v fish >/dev/null 2>&1 && command -v fisher >/dev/null 2>&1; then
    if fish -c "fisher update" </dev/null; then
      ok "fisher updated (tide + fzf.fish ready)"
    else
      warn "fisher update failed — open fish and run: fisher update"
    fi
  else
    warn "fish/fisher not available yet — run \`fisher update\` in fish"
  fi
}

# ── Banner / final summary ───────────────────────────────────────────────────
banner() {
  printf '\n%s╔══════════════════════════════════════════════╗%s\n' "$C_BL$C_B" "$C_R"
  printf '%s║   egaldidots · bootstrap · CachyOS / Arch     ║%s\n' "$C_BL$C_B" "$C_R"
  printf '%s╚══════════════════════════════════════════════╝%s\n\n' "$C_BL$C_B" "$C_R"
}

next_steps() {
  [ "$DO_STOW" -eq 1 ] || return 0
  local bak="(no backup needed)"
  [ "$DO_BACKUP" -eq 1 ] && [ -d "$BACKUP_DIR" ] && bak="$BACKUP_DIR"
  step "Next steps"
  cat <<EOF
  ${C_DIM}1.${C_R} Pick a wallpaper to seed the pywal palette:
       ${C_G}wal -i ~/Wallpapers/<your-wall>.png${C_R}
       ${C_DIM}(or use the Super+W keybind in Hyprland — wallpaper picker)${C_R}
     That generates ${C_G}~/.cache/wal/${C_R} and the whole rice auto-colors (bar, menu,
     lock, terminal, editor, fastfetch) from that wallpaper.

  ${C_DIM}2.${C_R} GRUB / SDDM themes need sudo → ${C_B}see README.md${C_R} (manual steps).
     install.sh doesn't touch system paths, by design.

  ${C_DIM}3.${C_R} Previous config backup (if there were conflicts):
       ${C_DIM}$bak${C_R}
EOF
}

# ── Flags ────────────────────────────────────────────────────────────────────
DO_DEPS=1; DO_STOW=1; DO_BACKUP=1; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --deps-only) DO_STOW=0   ;;
    --stow-only) DO_DEPS=0    ;;
    --no-backup) DO_BACKUP=0  ;;
    --force)     FORCE=1      ;;
    -h|--help)   print_help; exit 0 ;;
    *) err "unknown argument: $1 (see --help)"; exit 2 ;;
  esac
  shift
done

# ── Main ─────────────────────────────────────────────────────────────────────
banner
[ -d "$STOW_DIR/.config" ] || [ -d "$STOW_DIR/hypr" ] \
  || die "$STOW_DIR doesn't look like the egaldidots repo (missing .config/ or hypr/)"
detect_os

if [ "$DO_STOW" -eq 1 ] && [ "$DO_BACKUP" -eq 1 ]; then
  mkdir -p "$BACKUP_DIR"
fi

if [ "$DO_DEPS" -eq 1 ]; then install_deps; fi
if [ "$DO_STOW" -eq 1 ]; then enlace;        fi
if [ "$DO_STOW" -eq 1 ]; then post_fisher;   fi

next_steps
printf '\n'
ok "Done. Open a fish shell and Hyprland to see the rice. 🎨\n"
