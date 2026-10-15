# Isla Matugen consumers

`templates/manifest.json` lists the six native Matugen templates. The wallpaper
pipeline renders them in one pass, validates the palette, and publishes each
`~/.cache/matugen/outputs/<output>` link together with `palette.json` and
`current-wallpaper`. Consumers should reload only after that publish succeeds.

The generated files serve Hyprland/Hyprlock, Kitty, Rofi, Waybar, SwayNC,
wlogout, GTK3/4, and Fish. Starship and Neovim read the canonical
`palette.json` directly. Fish refreshes on `matugen_sync_signal`; Neovim uses
`SIGUSR1`. GTK defaults to Adwaita. Generated standard GTK aliases and a small user CSS
layer color native windows, headerbars, controls, and lists; file choosers keep
subtle glass. Newly opened GTK apps read the published stylesheet. Existing
processes may retain their loaded provider until they reopen; the pipeline does
not toggle `org.gnome.desktop.interface gtk-theme` or terminate applications.
Libadwaita applications may ignore GTK CSS customizations; the GTK4 rule
applies where the toolkit permits user CSS.

The runtime pipeline builds a temporary Matugen config from the manifest;
`config.toml` records local defaults and is not its template registry.
