----------------------
---   AUTOSTART    ---
----------------------
-- Autostart de procesos necesarios. En Lua se ejecuta en el evento hyprland.start.

hl.on("hyprland.start", function()
    -- Topbar quickshell "Isla" (dynamic island · vidrio Matugen · morph Ricelin) · config `bar`.
    hl.exec_cmd(require("modules.isla").script("start-isla.sh"))

    -- Wallpaper del boot: usa el symlink current-wallpaper (lo mantiene Matugen)
    -- → ÚNICA fuente de verdad: el wallpaper que se muestra es el mismo cuyos colores aplica bash ~/.config/hypr/scripts/apply-wallpaper.sh --refresh.
    hl.exec_cmd([[bash -c "killall -q awww-daemon; awww-daemon & sleep 1 && WP=$(readlink -f ~/.cache/matugen/current-wallpaper); [ -f \"$WP\" ] && awww img \"$WP\" --transition-type wipe --transition-fps 144"]])
    hl.exec_cmd([[bash -c "sleep 2 && bash ~/.config/hypr/scripts/apply-wallpaper.sh --refresh"]])

    -- Clipboard history (texto e imágenes)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Persistencia del portapapeles y keyring
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")

end)