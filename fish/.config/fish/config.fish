# CachyOS base config (sourced when present; skipped on plain Arch)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# ── Pywal + Tide ──────────────────────────────────────────────────────────
# pywal defines fish_color_* in colors.fish but colorN live in colors.sh
# (color7='#rrggbb'); import them so the $colorN refs below resolve.
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

# Mix two #rrggbb by t∈[0,1] (0→hex1, 1→hex2). Used to derive the
# powerline divider by darkening the wallpaper bg.
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

# ── Tide theme derived from the wallpaper (pywal) ────────────────────────
# Only COLORS are set here (structure lives in tide-structure.fish) so the
# prompt tracks the wallpaper. Semantic accents (git stages, status ok/fail,
# vi, langs) are FIXED catppuccin/Nord, not pywal — adjacent pywal slots
# collapse on light palettes and ok vs fail would stop reading as distinct.
# Fixed-slate fallback when pywal is absent.
function __tide_pywal_apply --description "Color Tide from pywal (fixed-slate fallback)"
    __wal_load_palette
    set -l have
    if set -q color8; and test -n "$color8"
        set have 1
    end

    set -l bg; set -l div
    if test -n "$have"
        set bg $color8                     # bright-black of the wallpaper (tinted gray)
        set div (__wal_hex_mix $color8 000000 0.55)  # divider = bg darkened
    else
        set bg 2E323D; set div 4A5366      # slate fijo (fallback)
    end

    # ── cohesive bg: every segment shares one color ──
    # (v = exact suffix after `tide_`; the vars already end in `_bg_color`)
    for v in pwd_bg_color os_bg_color git_bg_color git_bg_color_unstable git_bg_color_urgent \
             vi_mode_bg_color_default vi_mode_bg_color_insert vi_mode_bg_color_replace vi_mode_bg_color_visual \
             status_bg_color cmd_duration_bg_color jobs_bg_color context_bg_color time_bg_color \
             python_bg_color node_bg_color direnv_bg_color docker_bg_color go_bg_color rustc_bg_color \
             java_bg_color php_bg_color ruby_bg_color elixir_bg_color crystal_bg_color nix_shell_bg_color \
             pulumi_bg_color terraform_bg_color aws_bg_color bun_bg_color kubectl_bg_color gcloud_bg_color \
             distrobox_bg_color toolbox_bg_color zig_bg_color private_mode_bg_color shlvl_bg_color
        set -U tide_$v $bg
    end
    # orphan bg vars from a previous malformed loop → delete
    for j in tide_git_bg_color_unstable_bg_color tide_git_bg_color_urgent_bg_color \
             tide_vi_mode_bg_color_default_bg_color tide_vi_mode_bg_color_insert_bg_color \
             tide_vi_mode_bg_color_replace_bg_color tide_vi_mode_bg_color_visual_bg_color
        set -qU $j; and set -eU $j
    end
    set -U tide_status_bg_color_failure 9E2A2A   # fixed red alert

    set -U tide_prompt_color_separator_same_color $div
    set -U tide_prompt_color_frame_and_connection $div

    # ── text: wallpaper-tinted where it breaks no semantic ──
    if test -n "$have"
        set -U tide_pwd_color_dirs           $color7    # wallpaper fg
        set -U tide_git_color_branch        $color12   # bright blue
        set -U tide_os_color                $color15   # OS icon
    else
        set -U tide_pwd_color_dirs           8FA9C0
        set -U tide_git_color_branch         7FD68B
        set -U tide_os_color                 E6EDF3
    end
    # current dir always pops (catppuccin) → stands out on any palette
    set -U tide_pwd_color_anchors        C8D6E5
    set -U tide_pwd_color_truncated_dirs 6A7B8C

    # ── FIXED accents (semantic: never depend on the wallpaper) ──
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

# Apply pywal to fish syntax (fish_color_*) and re-derive the Tide theme
# from the current palette. Called at startup and from __wal_sync (wallpaper
# change), so the prompt recolors live.
function __wal_apply_colors --description "Refresh fish_color_* and the Tide theme from pywal"
    test -f ~/.cache/wal/colors.fish; and source ~/.cache/wal/colors.fish
    __wal_load_palette

    # fish syntax (text you type, not the Tide prompt)
    set -g fish_color_command $color7 --bold
    set -g fish_color_param    $color15
    set -g fish_color_error    $color9
    set -g fish_color_comment  $color8

    # tide — wallpaper-derived theme
    __tide_pywal_apply
end

# Apply at startup (interactive shells only)
if status is-interactive
    __wal_apply_colors
end

# Recolor live on wallpaper change (picker sets $wal_sync_signal).
# Re-source _tide_pwd + _tide_cache_variables: Tide bakes them once at load.
function __wal_sync --on-variable wal_sync_signal
    __wal_apply_colors
    if status is-interactive
        _tide_cache_variables                 # re-bake separator (+git branch color) from new univs
        source (functions --details _tide_pwd) # re-bake _tide_pwd: pwd text/bg to new color8
        set -e _tide_repaint 2>/dev/null      # let next fish_prompt spawn a fresh job
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
