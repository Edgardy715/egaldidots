#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# install.sh · egaldidots bootstrap (Arch / CachyOS)
# ═══════════════════════════════════════════════════════════════════════════
# Instala las dependencias (pacman + AUR vía yay/paru), respalda cualquier
# config preexistente con sello de tiempo, y enlaza los paquetes con GNU Stow
# dentro de $HOME.
#
#   NUNCA toca /etc, /usr ni /boot directamente: los pasos que requieren sudo
#   para rutas del sistema (GRUB/SDDM themes) viven SÓLO documentados en el
#   README.md. Las dependencias se instalan vía el gestor de paquetes (que es
#   quien administra esas rutas), no a mano.
#
#   Uso:
#     ./install.sh                 # todo: deps + backup + stow + fisher
#     ./install.sh --stow-only     # saltea deps (ya todo instalado)
#     ./install.sh --deps-only     # sólo instala paquetes
#     ./install.sh --no-backup     # no respalda (sobreescribe/pisa conflictos)
#     ./install.sh --force         # continúa aunque no sea Arch/CachyOS
#     ./install.sh --help
#
set -euo pipefail

# ── Configuración ───────────────────────────────────────────────────────────
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
BACKUP_BASE="$HOME/.egaldidots-backup"
BACKUP_DIR="$BACKUP_BASE-$(date +%Y%m%d-%H%M%S)"

# Paquetes stow = un directorio de nivel superior del repo cada uno.
STOW_PKGS=(
  hypr waybar rofi wlogout swaync kitty fish fastfetch
  nvim micro bat wal wpg gtk thunar git wallpapers
)

# Dependencias oficiales (pacman) — derivadas de lo que REALMENTE usan los
# configs/scripts del repo (compositor+lock+idle · barra/menus/notis · shell
# · terminales/editores · utils de shell · media/clip/brillo/screens · fuentes
# nerd · stow para enlazar · fisher, que en CachyOS/extra es un bin oficial).
PACMAN_PKGS=(
  hyprland hypridle hyprlock
  waybar rofi wlogout swaync
  fish kitty neovim micro fastfetch
  bat eza zoxide fzf fd ripgrep lazygit jq
  playerctl wl-clipboard cliphist wl-clip-persist brightnessctl hyprshot
  libnotify gnome-keyring pavucontrol thunar imagemagick
  awww fisher ttf-jetbrains-mono-nerd stow
)

# Dependencias AUR (no en repos oficiales):
#   python-pywal16 · fork 16-colores de pywal, provee el comando `wal`
#   wpgtk          · gestor de wallpapers/GTK, provee `wpg` (genera FlatColor)
AUR_PKGS=( python-pywal16 wpgtk )

# ── Colores (se desactivan si no es una TTY) ─────────────────────────────────
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

# ── Detección de Arch / CachyOS (warn + abort si no) ──────────────────────────
detect_os() {
  [ -r /etc/os-release ] || die "no se pudo leer /etc/os-release (¿no es Arch?)"
  . /etc/os-release 2>/dev/null
  local id ok=""
  for id in ${ID:-} ${ID_LIKE:-}; do
    case "$id" in arch|cachyos) ok=1; break;; esac
  done
  if [ -z "$ok" ]; then
    warn "SO no detectado como Arch/CachyOS — ID='${ID:-}' ID_LIKE='${ID_LIKE:-}'"
    [ "$FORCE" -eq 1 ] || die "abortando. Usá --force para continuar bajo tu riesgo."
    warn "--force activado: continúo igual."
  else
    ok "SO: $NAME  (ID=$ID, ID_LIKE=${ID_LIKE:-})"
  fi
}

# ── Respaldo (timestamp) de configs preexistentes, file a file ──────────────
# Mueve a $BACKUP_DIR sólo los archivos que el repo TAMBIÉN provee y que ya
# existen en $HOME como archivos reales (o symlinks ajenos). Deja intacto
# todo lo demás. Idempotente: los symlinks ya gestados por este repo se saltan.
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
        continue   # ya enlazado por este repo → no se toca
      fi
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      mv -f "$target" "$BACKUP_DIR/$rel"
      printf '   %sbackup%s  ~/%s\n' "$C_DIM" "$C_R" "$rel"
    done )
}

# ── Instalación de dependencias ─────────────────────────────────────────────
install_deps() {
  step "Dependencias oficiales (pacman)"
  local pacman_bin="pacman"
  [ "$(id -u)" -eq 0 ] || pacman_bin="sudo pacman"
  $pacman_bin -Sy --noconfirm >/dev/null \
    || die "pacman -Sy falló (¿red? ¿keyring? probá: sudo pacman -Sy archlinux-keyring)"
  if ! $pacman_bin -S --needed --noconfirm "${PACMAN_PKGS[@]}"; then
    die "pacman falló instalando: ${PACMAN_PKGS[*]}"
  fi
  ok "dependencias oficiales OK"

  step "Dependencias AUR (${AUR_PKGS[*]})"
  local helper=""
  command -v yay  >/dev/null 2>&1 && helper="yay"
  [ -z "$helper" ] && command -v paru >/dev/null 2>&1 && helper="paru"
  if [ -z "$helper" ]; then
    warn "no hay yay/paru. Instalá uno (AUR) y luego:"
    warn "    ${helper:-yay} -S --needed ${AUR_PKGS[*]}"
    warn "pywal y wpgtk mueven la paleta dinámica del rice — son necesarios."
    return 0
  fi
  if $helper -S --needed --noconfirm "${AUR_PKGS[@]}"; then
    ok "dependencias AUR OK"
  else
    warn "$helper falló con AUR — instalá a mano: ${AUR_PKGS[*]}"
  fi
}

# ── Enlazado con GNU Stow ──────────────────────────────────────────────────
enlace() {
  command -v stow >/dev/null 2>&1 \
    || die "falta \`stow\`. Instalá deps primero: ./install.sh --deps-only"
  step "Enlazando ${#STOW_PKGS[@]} paquetes con stow → $TARGET"
  local pkg
  for pkg in "${STOW_PKGS[@]}"; do
    [ -d "$STOW_DIR/$pkg" ] || { warn "paquete '$pkg' no existe en repo — lo salto"; continue; }
    if [ "$DO_BACKUP" -eq 1 ]; then backup_pkg "$pkg"; fi
    if stow -R -d "$STOW_DIR" -t "$TARGET" "$pkg"; then
      ok "stow $pkg"
    else
      err "stow falló para '$pkg' (verificá conflictos residuales en ~)"
      return 1
    fi
  done
}

# ── Post: plugins de fish (tide + fzf.fish) ─────────────────────────────────
post_fisher() {
  step "Plugins de fish (fisher: tide + fzf.fish)"
  if command -v fish >/dev/null 2>&1 && command -v fisher >/dev/null 2>&1; then
    if fish -c "fisher update" </dev/null; then
      ok "fisher actualizado (tide + fzf.fish listos)"
    else
      warn "fisher update falló — abrí fish y ejecutá: fisher update"
    fi
  else
    warn "fish/fisher aún no disponibles — ejecutá \`fisher update\` en fish"
  fi
}

# ── Banner / resumen final ──────────────────────────────────────────────────
banner() {
  printf '\n%s╔══════════════════════════════════════════════╗%s\n' "$C_BL$C_B" "$C_R"
  printf '%s║   egaldidots · bootstrap · CachyOS / Arch     ║%s\n' "$C_BL$C_B" "$C_R"
  printf '%s╚══════════════════════════════════════════════╝%s\n\n' "$C_BL$C_B" "$C_R"
}

next_steps() {
  [ "$DO_STOW" -eq 1 ] || return 0
  local bak="(sin backup necesario)"
  [ "$DO_BACKUP" -eq 1 ] && [ -d "$BACKUP_DIR" ] && bak="$BACKUP_DIR"
  step "Próximos pasos"
  cat <<EOF
  ${C_DIM}1.${C_R} Elegí un wallpaper para sembrar la paleta pywal:
       ${C_G}wal -i ~/Wallpapers/<tu-wall>.png${C_R}
       ${C_DIM}(o usá el keybind Super+W en Hyprland — picker de wallpapers)${C_R}
     Eso genera ${C_G}~/.cache/wal/${C_R} y todo el rice se auto-colorea (bar, menu,
     lock, terminal, editor, fastfetch) a partir de ese wallpaper.

  ${C_DIM}2.${C_R} GRUB / SDDM themes requieren sudo → ${C_B}ver README.md${C_R} (pasos manuales).
     install.sh no toca rutas del sistema, por diseño.

  ${C_DIM}3.${C_R} Backup previo de tu config (si hubo conflictos):
       ${C_DIM}$bak${C_R}
EOF
}

# ── Flags ───────────────────────────────────────────────────────────────────
DO_DEPS=1; DO_STOW=1; DO_BACKUP=1; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --deps-only) DO_STOW=0   ;;
    --stow-only) DO_DEPS=0    ;;
    --no-backup) DO_BACKUP=0  ;;
    --force)     FORCE=1      ;;
    -h|--help)   print_help; exit 0 ;;
    *) err "argumento desconocido: $1 (ver --help)"; exit 2 ;;
  esac
  shift
done

# ── Main ─────────────────────────────────────────────────────────────────────
banner
[ -d "$STOW_DIR/.config" ] || [ -d "$STOW_DIR/hypr" ] \
  || die "$STOW_DIR no parece el repo egaldidots (falta .config/ o hypr/)"
detect_os

if [ "$DO_STOW" -eq 1 ] && [ "$DO_BACKUP" -eq 1 ]; then
  mkdir -p "$BACKUP_DIR"
fi

if [ "$DO_DEPS" -eq 1 ]; then install_deps; fi
if [ "$DO_STOW" -eq 1 ]; then enlace;        fi
if [ "$DO_STOW" -eq 1 ]; then post_fisher;   fi

next_steps
printf '\n'
ok "Listo. Abrí una fish shell y Hyprland para ver el rice. 🎨\n"
