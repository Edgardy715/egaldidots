# ═════════════════════════════════════════════════════════════════════════
# tide-structure.fish · Estructura (no-colores) del prompt de Tide
# ═════════════════════════════════════════════════════════════════════════
# Los COLORES de Tide los deriva config.fish desde pywal (__tide_pywal_apply),
# así que acá viven SÓLO las variables ESTRUCTURALES: qué ítems se muestran,
# los separadores powerline, los iconos nerd-font, paddings, frame, transient
# y los trazos de git/time. Se siembran como universales para que un arranque
# limpio reproduzca el mismo prompt sin necesidad de `tide configure`.
#
# Generado a partir de mi fish_variables original, EXCLUYENDO:
#   • pure_*            (prompt "pure" que ya no tengo instalado — vars huérfanas)
#   • _fisher_*         (los regenera fisher desde fish_plugins)
#   • _tide_prompt_*    (caches de render efímeros; tide los recalcula)
#   • fish_user_paths, wal_sync_signal, __fish_initialized, __done_*  (runtime/OS)
#   • todos los *_bg_color y *_color  (viajan con el wallpaper vía config.fish)
#
# Idempotente: re-setear universales en cada shell interactiva es inofensivo y
# garantiza que el prompt siempre coincida con el repo. Si querés customizar el
# prompt, editá ESTE archivo (es la fuente de verdad) y no corras `tide
# configure` (sus cambios se perderían en el siguiente arranque).

if status is-interactive
    # ── Layout: ítems a izquierda / derecha ──
    set -U tide_left_prompt_items  vi_mode os pwd git
    set -U tide_right_prompt_items status cmd_duration time context jobs node python

    # ── Frame / espaciado / transient ──
    set -U tide_left_prompt_frame_enabled  false
    set -U tide_right_prompt_frame_enabled false
    set -U tide_prompt_add_newline_before  true
    set -U tide_prompt_pad_items           true
    set -U tide_prompt_transient_enabled   true
    set -U tide_prompt_min_cols            34
    set -U tide_prompt_icon_connection     " "

    # ── Separadores powerline (izquierda) ──
    set -U tide_left_prompt_prefix                ""
    set -U tide_left_prompt_suffix                ""
    set -U tide_left_prompt_separator_diff_color  ""
    set -U tide_left_prompt_separator_same_color  ""

    # ── Separadores powerline (derecha) ──
    set -U tide_right_prompt_prefix               ""
    set -U tide_right_prompt_suffix               ""
    set -U tide_right_prompt_separator_diff_color ""
    set -U tide_right_prompt_separator_same_color ""

    # ── Ítem: character / status ──
    set -U tide_character_icon              "❯"
    set -U tide_character_vi_icon_default   "❮"
    set -U tide_character_vi_icon_replace   "▶"
    set -U tide_character_vi_icon_visual    V
    set -U tide_status_icon                  "✔"
    set -U tide_status_icon_failure          "✘"

    # ── Ítem: os / pwd ──
    set -U tide_os_icon            ""
    set -U tide_pwd_icon            ""
    set -U tide_pwd_icon_home       ""
    set -U tide_pwd_icon_unwritable ""
    set -U tide_pwd_markers .bzr .citc .git .hg .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS go.mod package.json build.zig

    # ── Ítem: git ──
    set -U tide_git_icon               ""
    set -U tide_git_truncation_length    24
    set -U tide_git_truncation_strategy  "\x1d"

    # ── Ítem: cmd_duration / time / context / jobs ──
    set -U tide_cmd_duration_icon        ""
    set -U tide_cmd_duration_decimals     0
    set -U tide_cmd_duration_threshold    3000
    set -U tide_time_format             "%H:%M"
    set -U tide_context_always_display    false
    set -U tide_context_hostname_parts    1
    set -U tide_jobs_icon                 ""
    set -U tide_jobs_number_threshold      1000
    set -U tide_shlvl_threshold            1

    # ── Iconos de lenguajes / herramientas (nerd-font Private-Use-Area) ──
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

    # ── Etiquetas de vi mode ──
    set -U tide_vi_mode_icon_default D
    set -U tide_vi_mode_icon_insert  I
    set -U tide_vi_mode_icon_replace R
    set -U tide_vi_mode_icon_visual  V

    # ── Excepciones de color no cubiertas por __tide_pywal_apply ──
    set -U tide_direnv_bg_color_denied brred
    set -U tide_direnv_color_denied     black
end
