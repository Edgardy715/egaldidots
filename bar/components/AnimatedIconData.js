.pragma library

// Figuras Lucide para iconos Material Symbols usados por Isla.
// Licencia ISC y fuente oficial: lucide-icons/lucide; ver docs/licenses/lucide.txt.
// Los nombres Material equivalentes comparten piezas (por ejemplo, power y
// power_settings_new); cada nodo SVG se conserva como un path independiente.
var _catalog = {
    "add": [
        { path: "M5 12h14", role: "draw" },
        { path: "M12 5v14", role: "draw" },
    ],
    "arrow_forward": [
        { path: "M5 12h14", role: "arrow" },
        { path: "m12 5 7 7-7 7", role: "arrow" },
    ],
    "battery_full": [
        { path: "M10 10v4", role: "draw" },
        { path: "M14 10v4", role: "draw" },
        { path: "M22 14v-4", role: "draw" },
        { path: "M6 10v4", role: "draw" },
        { path: "M4 6h12a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-8a2 2 0 0 1 2 -2Z", role: "body" },
    ],
    "battery_charging_full": [
        { path: "m11 7-3 5h4l-3 5", role: "draw" },
        { path: "M14.856 6H16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.935", role: "body" },
        { path: "M22 14v-4", role: "body" },
        { path: "M5.14 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2.936", role: "body" },
    ],
    "battery_alert": [
        { path: "M10 17h.01", role: "draw" },
        { path: "M10 7v6", role: "draw" },
        { path: "M14 6h2a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2", role: "body" },
        { path: "M22 14v-4", role: "body" },
        { path: "M6 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2", role: "body" },
    ],
    "bluetooth": [
        { path: "m7 7 10 10-5 5V2l5 5L7 17", role: "draw" },
    ],
    "bluetooth_disabled": [
        { path: "m17 17-5 5V12l-5 5", role: "draw" },
        { path: "m2 2 20 20", role: "draw" },
        { path: "M14.5 9.5 17 7l-5-5v4.5", role: "draw" },
    ],
    "brightness_7": [
        { path: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0Z", role: "draw" },
        { path: "M12 2v2", role: "draw" },
        { path: "M12 20v2", role: "draw" },
        { path: "m4.93 4.93 1.41 1.41", role: "draw" },
        { path: "m17.66 17.66 1.41 1.41", role: "draw" },
        { path: "M2 12h2", role: "draw" },
        { path: "M20 12h2", role: "draw" },
        { path: "m6.34 17.66-1.41 1.41", role: "draw" },
        { path: "m19.07 4.93-1.41 1.41", role: "draw" },
    ],
    "broken_image": [
        { path: "M2 2L22 22", role: "arrow" },
        { path: "M10.41 10.41a2 2 0 1 1-2.83-2.83", role: "draw" },
        { path: "M13.5 13.5L6 21", role: "draw" },
        { path: "M18 12L21 15", role: "draw" },
        { path: "M3.59 3.59A1.99 1.99 0 0 0 3 5v14a2 2 0 0 0 2 2h14c.55 0 1.052-.22 1.41-.59", role: "draw" },
        { path: "M21 15V5a2 2 0 0 0-2-2H9", role: "draw" },
    ],
    "calendar_month": [
        { path: "M8 2v3", role: "draw" },
        { path: "M16 2v3", role: "draw" },
        { path: "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2Z", role: "draw" },
        { path: "M3 9h18", role: "draw" },
        { path: "M8 13h.01", role: "draw" },
        { path: "M12 13h.01", role: "draw" },
        { path: "M16 13h.01", role: "draw" },
        { path: "M8 17h.01", role: "draw" },
        { path: "M12 17h.01", role: "draw" },
        { path: "M16 17h.01", role: "draw" },
    ],
    "chat": [
        { path: "M16 10a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 14.286V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z", role: "draw" },
        { path: "M20 9a2 2 0 0 1 2 2v10.286a.71.71 0 0 1-1.212.502l-2.202-2.202A2 2 0 0 0 17.172 19H10a2 2 0 0 1-2-2v-1", role: "draw" },
    ],
    "check": [
        { path: "M20 6 9 17l-5-5", role: "draw" },
    ],
    "check_circle": [
        { path: "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0Z", role: "draw" },
        { path: "m16 9-5.5 5.5L8 12", role: "draw" },
    ],
    "chevron_left": [
        { path: "m15 18-6-6 6-6", role: "arrow" },
    ],
    "chevron_right": [
        { path: "m9 18 6-6-6-6", role: "arrow" },
    ],
    "close": [
        { path: "M18 6 6 18", role: "draw" },
        { path: "m6 6 12 12", role: "draw" },
    ],
    "coffee": [
        { path: "M10 2v2", role: "draw" },
        { path: "M14 2v2", role: "draw" },
        { path: "M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1", role: "draw" },
        { path: "M6 2v2", role: "draw" },
    ],
    "delete": [
        { path: "M10 11v6", role: "draw" },
        { path: "M14 11v6", role: "draw" },
        { path: "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", role: "body" },
        { path: "M3 6h18", role: "body" },
        { path: "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2", role: "body" },
    ],
    "delete_sweep": [
        { path: "M16 5H3", role: "draw" },
        { path: "M11 12H3", role: "draw" },
        { path: "M16 19H3", role: "draw" },
        { path: "m15.5 9.5 5 5", role: "draw" },
        { path: "m20.5 9.5-5 5", role: "draw" },
    ],
    "description": [
        { path: "M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z", role: "draw" },
        { path: "M14 2v5a1 1 0 0 0 1 1h5", role: "draw" },
        { path: "M10 9H8", role: "draw" },
        { path: "M16 13H8", role: "draw" },
        { path: "M16 17H8", role: "draw" },
    ],
    "done": [
        { path: "M20 6 9 17l-5-5", role: "draw" },
    ],
    "download": [
        { path: "M12 15V3", role: "draw" },
        { path: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", role: "draw" },
        { path: "m7 10 5 5 5-5", role: "draw" },
    ],
    "fiber_manual_record": [
        { path: "M11 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0Z", role: "draw" },
        { path: "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0Z", role: "draw" },
    ],
    "hourglass_top": [
        { path: "M5 22h14", role: "draw" },
        { path: "M5 2h14", role: "draw" },
        { path: "M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22", role: "draw" },
        { path: "M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2", role: "draw" },
    ],
    "info": [
        { path: "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0Z", role: "draw" },
        { path: "M12 16v-4", role: "draw" },
        { path: "M12 8h.01", role: "draw" },
    ],
    "keyboard": [
        { path: "M10 8h.01", role: "draw" },
        { path: "M12 12h.01", role: "draw" },
        { path: "M14 8h.01", role: "draw" },
        { path: "M16 12h.01", role: "draw" },
        { path: "M18 8h.01", role: "draw" },
        { path: "M6 8h.01", role: "draw" },
        { path: "M7 16h10", role: "draw" },
        { path: "M8 12h.01", role: "draw" },
        { path: "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-16a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2Z", role: "draw" },
    ],
    "lock": [
        { path: "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2Z", role: "body" },
        { path: "M7 11V7a5 5 0 0 1 10 0v4", role: "shackle" },
    ],
    "lock_open": [
        { path: "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2Z", role: "body" },
        { path: "M7 11V7a5 5 0 0 1 9.9-1", role: "shackle" },
    ],
    "mail": [
        { path: "m22 7-8.991 5.727a2 2 0 0 1-2.009 0L2 7", role: "draw" },
        { path: "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-16a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2Z", role: "draw" },
    ],
    "mic": [
        { path: "M12 19v3", role: "draw" },
        { path: "M19 10v2a7 7 0 0 1-14 0v-2", role: "draw" },
        { path: "M12 2h0a3 3 0 0 1 3 3v7a3 3 0 0 1 -3 3h-0a3 3 0 0 1 -3 -3v-7a3 3 0 0 1 3 -3Z", role: "draw" },
    ],
    "mic_off": [
        { path: "M12 19v3", role: "draw" },
        { path: "M15 9.34V5a3 3 0 0 0-5.68-1.33", role: "draw" },
        { path: "M16.95 16.95A7 7 0 0 1 5 12v-2", role: "draw" },
        { path: "M18.89 13.23A7 7 0 0 0 19 12v-2", role: "draw" },
        { path: "m2 2 20 20", role: "draw" },
        { path: "M9 9v3a3 3 0 0 0 5.12 2.12", role: "draw" },
    ],
    "music_note": [
        { path: "M4 18a4 4 0 1 0 8 0a4 4 0 1 0 -8 0Z", role: "draw" },
        { path: "M12 18V2l7 4", role: "draw" },
    ],
    "music_off": [
        { path: "M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z", role: "body" },
        { path: "m16.5 14.5 5-5", role: "wave" },
        { path: "m16.5 9.5 5 5", role: "wave" },
    ],
    "play_circle": [
        { path: "M9 9.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997A1 1 0 0 1 9 14.996z", role: "draw" },
        { path: "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0Z", role: "draw" },
    ],
    "smart_display": [
        { path: "M15.033 9.44a.647.647 0 0 1 0 1.12l-4.065 2.352a.645.645 0 0 1-.968-.56V7.648a.645.645 0 0 1 .967-.56z", role: "draw" },
        { path: "M12 17v4", role: "draw" },
        { path: "M8 21h8", role: "draw" },
        { path: "M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-16a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2Z", role: "draw" },
    ],
    "notifications": [
        { path: "M10.268 21a2 2 0 0 0 3.464 0", role: "clapper" },
        { path: "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326", role: "bell" },
    ],
    "pause": [
        { path: "M15 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-16a1 1 0 0 1 1 -1Z", role: "draw" },
        { path: "M6 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-16a1 1 0 0 1 1 -1Z", role: "draw" },
    ],
    "person": [
        { path: "M7 8a5 5 0 1 0 10 0a5 5 0 1 0 -10 0Z", role: "draw" },
        { path: "M20 21a8 8 0 0 0-16 0", role: "draw" },
    ],
    "photo_camera": [
        { path: "M13.997 4a2 2 0 0 1 1.76 1.05l.486.9A2 2 0 0 0 18.003 7H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1.997a2 2 0 0 0 1.759-1.048l.489-.904A2 2 0 0 1 10.004 4z", role: "draw" },
        { path: "M9 13a3 3 0 1 0 6 0a3 3 0 1 0 -6 0Z", role: "draw" },
    ],
    "play_arrow": [
        { path: "M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z", role: "arrow" },
    ],
    "power": [
        { path: "M12 2v10", role: "stem" },
        { path: "M18.4 6.6a9 9 0 1 1-12.77.04", role: "arc" },
    ],
    "power_settings_new": [
        { path: "M12 2v10", role: "stem" },
        { path: "M18.4 6.6a9 9 0 1 1-12.77.04", role: "arc" },
    ],
    "progress_activity": [
        { path: "M21 12a9 9 0 1 1-6.219-8.56", role: "draw" },
    ],
    "refresh": [
        { path: "M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8", role: "rotate" },
        { path: "M21 3v5h-5", role: "rotate" },
    ],
    "restart_alt": [
        { path: "M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", role: "rotate" },
        { path: "M3 3v5h5", role: "rotate" },
    ],
    "dark_mode": [
        { path: "M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401", role: "draw" },
    ],
    "logout": [
        { path: "m16 17 5-5-5-5", role: "arrow" },
        { path: "M21 12H9", role: "arrow" },
        { path: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4", role: "body" },
    ],
    "repeat": [
        { path: "m17 2 4 4-4 4", role: "draw" },
        { path: "M3 11v-1a4 4 0 0 1 4-4h14", role: "draw" },
        { path: "m7 22-4-4 4-4", role: "draw" },
        { path: "M21 13v1a4 4 0 0 1-4 4H3", role: "draw" },
    ],
    "repeat_one": [
        { path: "m17 2 4 4-4 4", role: "draw" },
        { path: "M3 11v-1a4 4 0 0 1 4-4h14", role: "draw" },
        { path: "m7 22-4-4 4-4", role: "draw" },
        { path: "M21 13v1a4 4 0 0 1-4 4H3", role: "draw" },
        { path: "M11 10h1v4", role: "draw" },
    ],
    "schedule": [
        { path: "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0Z", role: "draw" },
        { path: "M12 6v6h4", role: "draw" },
    ],
    "search": [
        { path: "m21 21-4.34-4.34", role: "draw" },
        { path: "M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0Z", role: "draw" },
    ],
    "settings": [
        { path: "M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915", role: "gear" },
        { path: "M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0Z", role: "static" },
    ],
    "shuffle": [
        { path: "m18 14 4 4-4 4", role: "draw" },
        { path: "m18 2 4 4-4 4", role: "draw" },
        { path: "M2 18h1.973a4 4 0 0 0 3.3-1.7l5.454-8.6a4 4 0 0 1 3.3-1.7H22", role: "draw" },
        { path: "M2 6h1.972a4 4 0 0 1 3.6 2.2", role: "draw" },
        { path: "M22 18h-6.041a4 4 0 0 1-3.3-1.8l-.359-.45", role: "draw" },
    ],
    "skip_next": [
        { path: "M21 4v16", role: "arrow" },
        { path: "M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z", role: "arrow" },
    ],
    "skip_previous": [
        { path: "M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432z", role: "arrow" },
        { path: "M3 20V4", role: "arrow" },
    ],
    "speed": [
        { path: "m12 14 4-4", role: "draw" },
        { path: "M3.34 19a10 10 0 1 1 17.32 0", role: "draw" },
    ],
    "star": [
        { path: "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z", role: "draw" },
    ],
    "system_update": [
        { path: "M12 15V3", role: "draw" },
        { path: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", role: "draw" },
        { path: "m7 10 5 5 5-5", role: "draw" },
    ],
    "terminal": [
        { path: "M12 19h8", role: "draw" },
        { path: "m4 17 6-6-6-6", role: "draw" },
    ],
    "translate": [
        { path: "m5 8 6 6", role: "draw" },
        { path: "m4 14 6-6 2-3", role: "draw" },
        { path: "M2 5h12", role: "draw" },
        { path: "M7 2h1", role: "draw" },
        { path: "m22 22-5-10-5 10", role: "draw" },
        { path: "M14 18h6", role: "draw" },
    ],
    "video_library": [
        { path: "m16 6 4 14", role: "draw" },
        { path: "M12 6v14", role: "draw" },
        { path: "M8 8v12", role: "draw" },
        { path: "M4 4v16", role: "draw" },
    ],
    "volume_down": [
        { path: "M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z", role: "body" },
        { path: "M16 9a5 5 0 0 1 0 6", role: "wave" },
    ],
    "volume_mute": [
        { path: "M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z", role: "body" },
        { path: "M16 9a5 5 0 0 1 0 6", role: "wave" },
    ],
    "volume_off": [
        { path: "M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z", role: "body" },
        { path: "m16.5 14.5 5-5", role: "wave" },
        { path: "m16.5 9.5 5 5", role: "wave" },
    ],
    "volume_up": [
        { path: "M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z", role: "body" },
        { path: "M16 9a5 5 0 0 1 0 6", role: "wave" },
        { path: "M19.364 18.364a9 9 0 0 0 0-12.728", role: "wave" },
    ],
    "wallpaper": [
        { path: "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2Z", role: "draw" },
        { path: "M7 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0Z", role: "draw" },
        { path: "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21", role: "draw" },
    ],
    "warning": [
        { path: "m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3", role: "draw" },
        { path: "M12 9v4", role: "draw" },
        { path: "M12 17h.01", role: "draw" },
    ],
    "wb_sunny": [
        { path: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0Z", role: "draw" },
        { path: "M12 2v2", role: "draw" },
        { path: "M12 20v2", role: "draw" },
        { path: "m4.93 4.93 1.41 1.41", role: "draw" },
        { path: "m17.66 17.66 1.41 1.41", role: "draw" },
        { path: "M2 12h2", role: "draw" },
        { path: "M20 12h2", role: "draw" },
        { path: "m6.34 17.66-1.41 1.41", role: "draw" },
        { path: "m19.07 4.93-1.41 1.41", role: "draw" },
    ],
    "wifi": [
        { path: "M12 20h.01", role: "body" },
        { path: "M2 8.82a15 15 0 0 1 20 0", role: "wave" },
        { path: "M5 12.859a10 10 0 0 1 14 0", role: "wave" },
        { path: "M8.5 16.429a5 5 0 0 1 7 0", role: "wave" },
    ],
    "wifi_off": [
        { path: "M12 20h.01", role: "body" },
        { path: "M8.5 16.429a5 5 0 0 1 7 0", role: "wave" },
        { path: "M5 12.859a10 10 0 0 1 5.17-2.69", role: "wave" },
        { path: "M19 12.859a10 10 0 0 0-2.007-1.523", role: "wave" },
        { path: "M2 8.82a15 15 0 0 1 4.177-2.643", role: "wave" },
        { path: "M22 8.82a15 15 0 0 0-11.288-3.764", role: "wave" },
        { path: "m2 2 20 20", role: "wave" },
    ],
    "cloud": [
        { path: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z", role: "draw" },
    ],
    "thunderstorm": [
        { path: "M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 .5 8.973", role: "body" },
        { path: "m13 12-3 5h4l-3 5", role: "wave" },
    ],
    "rainy_light": [
        { path: "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242", role: "body" },
        { path: "M8 19v1", role: "wave" },
        { path: "M8 14v1", role: "wave" },
        { path: "M16 19v1", role: "wave" },
        { path: "M16 14v1", role: "wave" },
        { path: "M12 21v1", role: "wave" },
        { path: "M12 16v1", role: "wave" },
    ],
    "water_drop": [
        { path: "M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z", role: "draw" },
    ],
    "ac_unit": [
        { path: "m10 20-1.25-2.5L6 18", role: "draw" },
        { path: "M10 4 8.75 6.5 6 6", role: "draw" },
        { path: "m14 20 1.25-2.5L18 18", role: "draw" },
        { path: "m14 4 1.25 2.5L18 6", role: "draw" },
        { path: "m17 21-3-6h-4", role: "draw" },
        { path: "m17 3-3 6 1.5 3", role: "draw" },
        { path: "M2 12h6.5L10 9", role: "draw" },
        { path: "m20 10-1.5 2 1.5 2", role: "draw" },
        { path: "M22 12h-6.5L14 15", role: "draw" },
        { path: "m4 10 1.5 2L4 14", role: "draw" },
        { path: "m7 21 3-6-1.5-3", role: "draw" },
        { path: "m7 3 3 6h4", role: "draw" },
    ],
    "foggy": [
        { path: "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242", role: "body" },
        { path: "M16 17H7", role: "wave" },
        { path: "M17 21H9", role: "wave" },
    ],
    "sunny": [
        { path: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0Z", role: "draw" },
        { path: "M12 2v2", role: "draw" },
        { path: "M12 20v2", role: "draw" },
        { path: "m4.93 4.93 1.41 1.41", role: "draw" },
        { path: "m17.66 17.66 1.41 1.41", role: "draw" },
        { path: "M2 12h2", role: "draw" },
        { path: "M20 12h2", role: "draw" },
        { path: "m6.34 17.66-1.41 1.41", role: "draw" },
        { path: "m19.07 4.93-1.41 1.41", role: "draw" },
    ],
    "partly_cloudy_night": [
        { path: "M13 16a3 3 0 0 1 0 6H7a5 5 0 1 1 4.9-6z", role: "wave" },
        { path: "M18.376 14.512a6 6 0 0 0 3.461-4.127c.148-.625-.659-.97-1.248-.714a4 4 0 0 1-5.259-5.26c.255-.589-.09-1.395-.716-1.248a6 6 0 0 0-4.594 5.36", role: "body" },
    ],
    "partly_cloudy_day": [
        { path: "M12 2v2", role: "wave" },
        { path: "m4.93 4.93 1.41 1.41", role: "wave" },
        { path: "M20 12h2", role: "wave" },
        { path: "m19.07 4.93-1.41 1.41", role: "wave" },
        { path: "M15.947 12.65a4 4 0 0 0-5.925-4.128", role: "wave" },
        { path: "M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z", role: "body" },
    ],
    "thermostat": [
        { path: "M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z", role: "draw" },
    ],
}

function parts(name) {
    return _catalog[name] || []
}
