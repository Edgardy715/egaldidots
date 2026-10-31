# Isla Matugen consumers

`templates/manifest.json` lists the native Matugen templates. The wallpaper
pipeline renders them in one pass, validates the palette, and publishes each
`~/.cache/matugen/outputs/<output>` link together with `palette.json` and
`current-wallpaper`. Consumers should reload only after that publish succeeds.

The generated files serve Hyprland/Hyprlock, Kitty, GTK3/4, and Fish. Starship and Neovim read the canonical
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

Without `--mode`, each generation reads the desktop `color-scheme` preference:
`prefer-dark` selects dark and `prefer-light` selects light. `default` means no
preference: it preserves the published mode, as do unavailable desktop settings.
A first seed without an explicit preference uses dark.
An explicit `--mode` overrides that generation and the GTK dark preference; the
desktop portal/GSettings appearance preference is preserved.
After changing desktop appearance, run `generate.py --refresh` to regenerate native
CSS and terminal colors. There is no background appearance watcher.

Qt uses the installed `gtk3` platform theme bridge instead of an unconfigured
qt6ct plugin. After publication, the pipeline updates only
`gtk-application-prefer-dark-theme` in GTK3/4 settings, preserving other keys and
file permissions. This is required because GTK3 does not follow the portal color
scheme by itself. Linked GTK settings or linked GTK directories are refused before
publication. The installer materializes only its own Stow GTK links as regular
files so generated mode preferences never modify repository sources. Electron and libadwaita keep
following the desktop portal preference, with no per-application palette overrides.
When the portal reports no preference (`default`), those applications may choose
their own appearance; preserving Isla’s published mode does not force their mode.
Qt, GTK and Electron use Wayland monitor scaling; the portable monitor rule uses
automatic scale and no global toolkit scale multiplier. XCursor's `default` theme
resolves through the installed icon theme (Adwaita on the supported installation).
Existing apps may need reopening; environment changes require a new session.
