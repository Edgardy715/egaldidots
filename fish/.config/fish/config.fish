# CachyOS base config (sourced when present; skipped on plain Arch)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# ── Pywal + Starship ──────────────────────────────────────────────────────────
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

# Sintaxis y prompt sincronizados con el wallpaper actual.
function __wal_apply_colors --description "Refresca los colores de Fish desde pywal"
    test -f ~/.cache/wal/colors.fish; and source ~/.cache/wal/colors.fish
    __wal_load_palette
    if command python3 ~/.config/starship/pywal.py
        set -gx STARSHIP_CONFIG ~/.cache/starship/pywal.toml
    end
    if set -q color7 color15 color9 color8
        set -g fish_color_command $color7 --bold
        set -g fish_color_param $color15
        set -g fish_color_error $color9
        set -g fish_color_comment $color8
    end
end

if status is-interactive
    __wal_apply_colors
end

function __wal_sync --on-variable wal_sync_signal
    if status is-interactive
        __wal_apply_colors
        commandline -f repaint
    end
end

# cat → bat
alias cat='bat --paging=never'

# ── eza: ls with nerd-font icons (lsd/exa successor) ──
# ls → simple · ll → long + git · la → with hidden · lt → tree (depth 2)
alias ls='eza --group-directories-first --icons'
alias ll='eza -l --group-directories-first --icons --git'
alias la='eza -la --group-directories-first --icons --git'
alias lt='eza --tree --level=2 --group-directories-first --icons'

# ── zoxide: smart cd · z <substr> jumps to frequent dirs, zi = menu ──
# installs with: sudo pacman -S zoxide → activates only if present
if type -q zoxide
    zoxide init fish | source
end

# Visual theme
set -x BAT_THEME "Catppuccin Mocha"

# Use bat to view man pages with syntax highlighting
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
# No greeting
function fish_greeting
end
# Starship: prompt Isla, con historial compacto.
if status is-interactive; and type -q starship
    function starship_transient_prompt_func
        command starship module character $argv
    end
    starship init fish | source
    enable_transience
end
