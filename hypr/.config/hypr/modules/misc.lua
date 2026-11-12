-------------------
---     MISC     ---
-------------------
-- Ver https://wiki.hypr.land/Configuring/Variables

hl.config({
    misc = {
        vrr = 2,
        -- Si la pantalla de bloqueo de Isla se cae con la sesión bloqueada,
        -- lock.sh lanza hyprlock para relevarla (sin esto: pantalla roja y TTY).
        allow_session_lock_restore = true,
    },

    cursor = {
        no_hardware_cursors = 2,
    },
})