# Configuración base de CachyOS (si está presente; en Arch puro se omite)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# ── Pywal + Tide ──────────────────────────────────────────────────────────
# pywal solo define `fish_color_*` en colors.fish; las variables color0-15
# viven en colors.sh (formato `color7='#rrggbb'`). Las importamos a fish
# para que las referencias $colorN de abajo funcionen realmente.
function __wal_load_palette --description "Importa color0-15/fg/bg de pywal (~/.cache/wal/colors.sh)"
    test -f ~/.cache/wal/colors.sh; or return
    while read -l line
        set line (string trim -- (string replace -r '^export\s+' '' -- $line))
        test -z "$line"; and continue
        set -l kv (string split -m1 '=' -- $line); test (count $kv) -eq 2; or continue
        set -l name (string trim -- $kv[1])
        string match -q -- background  $name
        or string match -q -- foreground $name
        or string match -rq '^color([0-9]|1[0-5])$' -- $name
        or continue
        set -l val (string match -r '#[0-9a-fA-F]+' -- $kv[2])
        test -n "$val"; and set -g $name (string replace -i '#' '' -- $val)
    end < ~/.cache/wal/colors.sh
end

# Mezcla dos hex (#rrggbb) por t∈[0,1]; t=0→hex1, t=1→hex2. Sirve para
# derivar el divider (bar tint oscurecido) del fondo del wallpaper.
function __wal_hex_mix --argument-names hex1 hex2 t
    test -n "$hex1"; and test -n "$hex2"; or return
    set h1 (string replace -i '#' '' $hex1); set h2 (string replace -i '#' '' $hex2)
    set r1 (math 0x(string sub -l 2 $h1)); set g1 (math 0x(string sub -s 3 -l 2 $h1)); set b1 (math 0x(string sub -s 5 -l 2 $h1))
    set r2 (math 0x(string sub -l 2 $h2)); set g2 (math 0x(string sub -s 3 -l 2 $h2)); set b2 (math 0x(string sub -s 5 -l 2 $h2))
    set r (math "min(255, max(0, round($r1 + ($r2 - $r1) * $t)))")
    set g (math "min(255, max(0, round($g1 + ($g2 - $g1) * $t)))")
    set b (math "min(255, max(0, round($b1 + ($b2 - $b1) * $t)))")
    printf '%02X%02X%02X' $r $g $b
end

# ── Tema de Tide derivado del wallpaper (pywal) ──────────────────────────
# Mantiene la estructura cohesiva (barra única, dividers, paddings, time)
# que ya vive en las universales, pero deriva los COLORES de la paleta de
# pywal para que el prompt "sea del wallpaper". Los hemos dividido en:
#   • superficie dominante (fondo de todos los segmentos) → pywal color8
#     (bright-black = gris tintado por el wallpaper; NO es oscuro-fijo)
#   • divider / path / rama git / icono OS            → pywal (tintados)
#   • acentos semánticos (git staged/untracked, status ok/fail, vi, langs)
#     → FIJOS catppuccin/Nord: siempre legibles, sin importar el wallpaper,
#       porque en paletas muy claras los slots adyacentes de pywal colapsan
#       y (p.ej.) ok vs fail dejarían de distinguirse.
# Si no hay pywal cae al slate fijo. Se redefine en cada arranque y en cada
# cambio de wallpaper vía __wal_sync → __wal_apply_colors.
function __tide_pywal_apply --description "Colorea Tide desde pywal (fallback slate fijo)"
    __wal_load_palette
    set -l have
    if set -q color8; and test -n "$color8"
        set have 1
    end

    set -l bg; set -l div
    if test -n "$have"
        set bg $color8                     # bright-black del wallpaper (gris tintado)
        set div (__wal_hex_mix $color8 000000 0.55)  # divider = bg oscurecido
    else
        set bg 2E323D; set div 4A5366      # slate fijo (fallback)
    end

    # ── fondo cohesivo: todos los segmentos al mismo color ──
    # (v = sufijo exacto tras `tide_`; los vars ya terminan en `_bg_color`)
    for v in pwd_bg_color os_bg_color git_bg_color git_bg_color_unstable git_bg_color_urgent \
             vi_mode_bg_color_default vi_mode_bg_color_insert vi_mode_bg_color_replace vi_mode_bg_color_visual \
             status_bg_color cmd_duration_bg_color jobs_bg_color context_bg_color time_bg_color \
             python_bg_color node_bg_color direnv_bg_color docker_bg_color go_bg_color rustc_bg_color \
             java_bg_color php_bg_color ruby_bg_color elixir_bg_color crystal_bg_color nix_shell_bg_color \
             pulumi_bg_color terraform_bg_color aws_bg_color bun_bg_color kubectl_bg_color gcloud_bg_color \
             distrobox_bg_color toolbox_bg_color zig_bg_color private_mode_bg_color shlvl_bg_color
        set -U tide_$v $bg
    end
    # vars de fondo huérfanos (de un loop previo mal formado) → borrar
    for j in tide_git_bg_color_unstable_bg_color tide_git_bg_color_urgent_bg_color \
             tide_vi_mode_bg_color_default_bg_color tide_vi_mode_bg_color_insert_bg_color \
             tide_vi_mode_bg_color_replace_bg_color tide_vi_mode_bg_color_visual_bg_color
        set -qU $j; and set -eU $j
    end
    set -U tide_status_bg_color_failure 9E2A2A   # alerta roja siempre fija

    set -U tide_prompt_color_separator_same_color $div
    set -U tide_prompt_color_frame_and_connection $div

    # ── texto: tintado por el wallpaper donde no rompe semántica ──
    if test -n "$have"
        set -U tide_pwd_color_dirs           $color7    # fg del wallpaper
        set -U tide_git_color_branch        $color12   # azul brillante
        set -U tide_os_color                $color15   # icono OS
    else
        set -U tide_pwd_color_dirs           8FA9C0
        set -U tide_git_color_branch         7FD68B
        set -U tide_os_color                 E6EDF3
    end
    # current dir siempre "pop" (catppuccin) → se distingue sin importar paleta
    set -U tide_pwd_color_anchors        C8D6E5
    set -U tide_pwd_color_truncated_dirs 6A7B8C

    # ── acentos FIJOS (semánticos: nunca dependen del wallpaper) ──
    set -U tide_git_color_dirty     E0B860
    set -U tide_git_color_staged    E0B860
    set -U tide_git_color_untracked F0A0B0
    set -U tide_git_color_conflicted F08A8A
    set -U tide_git_color_operation F08A8A
    set -U tide_git_color_stash     7FD68B
    set -U tide_git_color_upstream  7FD68B
    set -U tide_cmd_duration_color  B0A070
    set -U tide_context_color_default D7AF87
    set -U tide_context_color_root    E0B860
    set -U tide_context_color_ssh     D7AF87
    set -U tide_jobs_color          7FD68B
    set -U tide_time_color          6A7B8C
    set -U tide_status_color        7FD68B
    set -U tide_status_color_failure F2C0C0
    set -U tide_character_color     7FD68B
    set -U tide_character_color_failure F08A8A
    set -U tide_vi_mode_color_default 8E9AAA
    set -U tide_vi_mode_color_insert  7FD68B
    set -U tide_vi_mode_color_replace E5C07B
    set -U tide_vi_mode_color_visual  C77DBA
    set -U tide_python_color F0C674; set -U tide_node_color A3BE8C; set -U tide_docker_color 8AB4F8
    set -U tide_go_color 7FD6E5;     set -U tide_rustc_color F0907A; set -U tide_java_color E5C07B
    set -U tide_php_color A9B6E5;     set -U tide_ruby_color F0909A;  set -U tide_elixir_color C792EA
    set -U tide_crystal_color E6EDF3; set -U tide_nix_shell_color A9D6E5; set -U tide_pulumi_color E0C07B
    set -U tide_terraform_color C792EA; set -U tide_aws_color E5B870; set -U tide_bun_color E0D6B0
    set -U tide_kubectl_color A9C6F0;  set -U tide_gcloud_color A9C6F0; set -U tide_distrobox_color E5A0E5
    set -U tide_toolbox_color C792EA;  set -U tide_zig_color E5C870; set -U tide_private_mode_color F2C0C0
    set -U tide_shlvl_color A9B6E5;    set -U tide_direnv_color E5C07B
end

# Aplica pywal a la SINTAXIS de fish (fish_color_*) Y re-deriva el tema de
# Tide desde la paleta actual. Llamado al arranque y desde __wal_sync (cambio
# de wallpaper), así el prompt recolorea en vivo.
function __wal_apply_colors --description "Refresca fish_color_* y el tema de Tide desde pywal"
    test -f ~/.cache/wal/colors.fish; and source ~/.cache/wal/colors.fish
    __wal_load_palette

    # fish — sintaxis (color del texto que escribes, no del prompt de Tide)
    set -g fish_color_command $color7 --bold
    set -g fish_color_param    $color15
    set -g fish_color_error    $color9
    set -g fish_color_comment  $color8

    # tide — tema derivado del wallpaper
    __tide_pywal_apply
end

# Aplicar al iniciar (sólo shells interactivos)
if status is-interactive
    __wal_apply_colors
end

# Re-aplicar en vivo cuando cambia el wallpaper. wallpaper-picker.sh hace
# `fish -c "set -U wal_sync_signal (date +%s)"`; ese cambio dispara este handler en
# cada shell interactiva. Además de actualizar las universales tide_*, hay DOS caches
# que Tide CONGELA al arrancar y que un simple `set -U` NO refresca (motivo por el
# que el segmento pwd "se quedaba con el color del wallpaper anterior" hasta
# cerrar/reabrir la terminal):
#   1. _tide_pwd — el TEXTO del pwd (color de las dirs + su fondo interno en
#      `reset_to_color_dirs`) se hornea UNA sola vez al cargar fish_prompt.fish
#      (`source (functions --details _tide_pwd)`). Cambiar tide_pwd_color_* NO
#      re-hornea la función → el pwd pintaba el texto con el color8 de arranque.
#      OJO: la CAJA del pwd (bg del segmento) sí es live (la pinta _tide_print_item
#      leyendo tide_pwd_bg_color a la vez); lo que se quedaba viejo era el texto.
#   2. _tide_cache_variables — hornea el divisor (tide_prompt_color_separator_*).
# Re-sourcear/re-correr AMBOS con las universales ya nuevas y luego forzar repaint
# = el pwd y el resto recolorean en vivo sin cerrar/reabrir. Verificado empíricamente
# (cambiar el color sin re-sourcear deja _tide_pwd con el valor viejo; re-sourcear
# lo renueva, y _tide_print_item usa el bg live).
function __wal_sync --on-variable wal_sync_signal
    __wal_apply_colors
    if status is-interactive
        _tide_cache_variables                 # re-hornea divisor (+color rama git) de las univ. nuevas
        source (functions --details _tide_pwd) # re-hornea _tide_pwd: texto/fondo del pwd al nuevo color8
        set -e _tide_repaint 2>/dev/null      # que el próximo fish_prompt lance un job fresco
        commandline -f repaint
    end
end

# Reemplaza cat por bat
alias cat='bat --paging=never'

# ── eza: ls con iconos nerd-font (sucesor de lsd/exa) ──
# ls → simple · ll → larga + git · la → con ocultos · lt → árbol (nivel 2)
alias ls='eza --group-directories-first --icons'
alias ll='eza -l --group-directories-first --icons --git'
alias la='eza -la --group-directories-first --icons --git'
alias lt='eza --tree --level=2 --group-directories-first --icons'

# ── zoxide: cd inteligente · z <substr> salta a dirs frecuentes, zi = menú ──
# (instala con: sudo pacman -S zoxide) → se activa solo al estar presente
if type -q zoxide
    zoxide init fish | source
end

# Tema visual
set -x BAT_THEME "Catppuccin Mocha"

# Usa bat para ver man pages con resaltado de sintaxis
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
# Quitar greeting
function fish_greeting
end
