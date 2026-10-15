# CachyOS base config (sourced when present; skipped on plain Arch)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# ── Matugen + Starship ────────────────────────────────────────────────────────
function __matugen_apply_colors --description "Refresca Fish y Starship desde Matugen"
    set -l cache_dir $HOME/.cache
    set -q XDG_CACHE_HOME; and set cache_dir $XDG_CACHE_HOME
    set -l config_dir $HOME/.config
    set -q XDG_CONFIG_HOME; and set config_dir $XDG_CONFIG_HOME
    if test -f $cache_dir/matugen/outputs/colors.fish
        source $cache_dir/matugen/outputs/colors.fish
    end
    if command python3 $config_dir/starship/matugen.py
        set -gx STARSHIP_CONFIG $cache_dir/starship/matugen.toml
    end
end

if status is-interactive
    __matugen_apply_colors
end

function __matugen_sync --on-variable matugen_sync_signal
    if status is-interactive
        __matugen_apply_colors
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
