# ═════════════════════════════════════════════════════════════════════════
# tide-structure.fish · Tide prompt STRUCTURE (no colors)
# ═════════════════════════════════════════════════════════════════════════
# Tide COLORS are pywal-derived in config.fish; this file holds only
# STRUCTURE (items, separators, icons, padding, frame, transient). Seeded as
# universals so a clean boot reproduces the prompt without `tide configure`.
# Colors, pure_*, _fisher_*, _tide_prompt_*, runtime vars are intentionally
# excluded (they live elsewhere / regenerate). Idempotent: re-setting univs
# each shell is harmless and keeps the prompt synced to the repo. Edit THIS
# file to customize — not `tide configure` (its changes would be lost on boot).

if status is-interactive
    # ── Layout: left / right items ──
    set -U tide_left_prompt_items  vi_mode os pwd git
    set -U tide_right_prompt_items status cmd_duration time context jobs node python

    # ── Frame / spacing / transient ──
    set -U tide_left_prompt_frame_enabled  false
    set -U tide_right_prompt_frame_enabled false
    set -U tide_prompt_add_newline_before  true
    set -U tide_prompt_pad_items           true
    set -U tide_prompt_transient_enabled   true
    set -U tide_prompt_min_cols            34
    set -U tide_prompt_icon_connection     " "

    # ── Powerline separators (left) ──
    set -U tide_left_prompt_prefix                ""
    set -U tide_left_prompt_suffix                ""
    set -U tide_left_prompt_separator_diff_color  ""
    set -U tide_left_prompt_separator_same_color  ""

    # ── Powerline separators (right) ──
    set -U tide_right_prompt_prefix               ""
    set -U tide_right_prompt_suffix               ""
    set -U tide_right_prompt_separator_diff_color ""
    set -U tide_right_prompt_separator_same_color ""

    # ── Item: character / status ──
    set -U tide_character_icon              "❯"
    set -U tide_character_vi_icon_default   "❮"
    set -U tide_character_vi_icon_replace   "▶"
    set -U tide_character_vi_icon_visual    V
    set -U tide_status_icon                  "✔"
    set -U tide_status_icon_failure          "✘"

    # ── Item: os / pwd ──
    set -U tide_os_icon            ""
    set -U tide_pwd_icon            ""
    set -U tide_pwd_icon_home       ""
    set -U tide_pwd_icon_unwritable ""
    set -U tide_pwd_markers .bzr .citc .git .hg .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS go.mod package.json build.zig

    # ── Item: git ──
    set -U tide_git_icon               ""
    set -U tide_git_truncation_length    24
    set -U tide_git_truncation_strategy  "\x1d"

    # ── Item: cmd_duration / time / context / jobs ──
    set -U tide_cmd_duration_icon        ""
    set -U tide_cmd_duration_decimals     0
    set -U tide_cmd_duration_threshold    3000
    set -U tide_time_format             "%H:%M"
    set -U tide_context_always_display    false
    set -U tide_context_hostname_parts    1
    set -U tide_jobs_icon                 ""
    set -U tide_jobs_number_threshold      1000
    set -U tide_shlvl_threshold            1

    # ── Language / tool icons (nerd-font Private-Use-Area) ──
    set -U tide_aws_icon       ""
    set -U tide_bun_icon       "\U000f0cd3"
    set -U tide_crystal_icon   ""
    set -U tide_direnv_icon    "▼"
    set -U tide_distrobox_icon "\U000f01a7"
    set -U tide_docker_icon    ""
    set -U tide_docker_default_contexts default colima
    set -U tide_elixir_icon    ""
    set -U tide_gcloud_icon    "\U000f02ad"
    set -U tide_go_icon        ""
    set -U tide_java_icon      ""
    set -U tide_kubectl_icon   "\U000f10fe"
    set -U tide_nix_shell_icon ""
    set -U tide_node_icon      ""
    set -U tide_php_icon       ""
    set -U tide_private_mode_icon "\U000f05f9"
    set -U tide_pulumi_icon    ""
    set -U tide_python_icon    "\U000f0320"
    set -U tide_ruby_icon      ""
    set -U tide_rustc_icon     ""
    set -U tide_terraform_icon "\U000f1062"
    set -U tide_toolbox_icon   ""
    set -U tide_zig_icon       ""

    # ── vi-mode labels ──
    set -U tide_vi_mode_icon_default D
    set -U tide_vi_mode_icon_insert  I
    set -U tide_vi_mode_icon_replace R
    set -U tide_vi_mode_icon_visual  V

    # ── Color exceptions not covered by __tide_pywal_apply ──
    set -U tide_direnv_bg_color_denied brred
    set -U tide_direnv_color_denied     black
end
