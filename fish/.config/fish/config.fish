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

# Sudo usa la pill de Quickshell como askpass. Se mantiene el binario real y
# sólo se añade -A, para que PAM siga siendo quien valide la contraseña.
function sudo --wraps /usr/bin/sudo --description 'sudo con la pill de Isla'
    set -lx SUDO_ASKPASS $HOME/.local/bin/isla-sudo-askpass
    # Respect stdin/explicit askpass options before the command, not its arguments.
    set -l askpass_option -A
    set -l option_value false
    for argument in $argv
        if $option_value
            set option_value false
            continue
        end
        switch $argument
            case --
                break
            case --stdin --askpass
                set askpass_option
            case --close-from --chdir --group --host --prompt --chroot --command-timeout --other-user --user --role --type
                set option_value true
            case '--*'
                continue
            case '-*'
                # A value-taking short option consumes the rest of its cluster.
                set -l flags (string replace -r '[CDghpRTUurt].*$' '' -- $argument)
                if string match -rq '[AS]' -- $flags
                    set askpass_option
                end
                if string match -rq '^-[^CDghpRTUurt]*[CDghpRTUurt]$' -- $argument
                    set option_value true
                end
            case '*'
                break
        end
    end
    # Validate before starting ordinary commands, including long-lived sudo su.
    # Options keep sudo's native semantics and bypass this preflight.
    if test (count $argv) -gt 0; and not string match -q -- '-*' $argv[1]
        set -lx ISLA_AUTH_ID (command cat /proc/sys/kernel/random/uuid)
        command /usr/bin/sudo -A -v
        set -l auth_status $status
        command qs -c bar ipc call sudoAuth validated "$ISLA_AUTH_ID" "$auth_status" >/dev/null 2>/dev/null
        if test $auth_status -ne 0
            return $auth_status
        end
        set -e ISLA_AUTH_ID
    end
    command /usr/bin/sudo $askpass_option $argv
    set -l sudo_status $status
    return $sudo_status
end

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
