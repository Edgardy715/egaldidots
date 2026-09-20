pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/**
 * Isla · Icons. Iconos Material Symbols Rounded (fuente variable de Google)
 * usados por su NOMBRE con ligaduras — igual que caelestia/utils/Icons.qml:
 * el `text` es el nombre del glifo (ej. "wifi_off") y la fuente lo convierte
 * al icono automáticamente. La familia vive en MaterialIcon.qml.
 *
 * Codepoints de Nerd Font NO se usan: la asignación f0001-f1af0 de los MDI en
 * Nerd Font no coincide con los nombres (por eso algunos glifos se veían
 * equivocados, como un "copiar" donde iba wifi).
 */
Singleton {
    id: root

    // ── Iconos base Material Symbols (por nombre, ligaduras) ────────────────
    readonly property string iBell:      "notifications"
    readonly property string iPower:     "power"
    readonly property string iRecord:    "fiber_manual_record"
    readonly property string iUpdate:    "system_update"
    readonly property string iDownload:  "download"
    readonly property string iMail:      "mail"
    readonly property string iCalendar:  "calendar_month"
    readonly property string iChat:      "chat"
    readonly property string iMusic:     "music_note"
    readonly property string iVideo:     "video_library"
    readonly property string iWarning:   "warning"
    readonly property string iLock:      "lock"
    readonly property string iWifi:      "wifi"
    readonly property string iVolume:    "volume_up"
    readonly property string iFile:      "description"
    readonly property string iBattery:   "battery_full"
    readonly property string iClock:     "schedule"
    readonly property string iWeather:   "wb_sunny"
    readonly property string iPerson:    "person"
    readonly property string iSettings:  "settings"
    readonly property string iCamera:    "photo_camera"
    readonly property string iTerminal:  "terminal"
    readonly property string iInfo:      "info"
    readonly property string iSearch:    "search"
    readonly property string iStar:      "star"
    readonly property string iClose:     "close"
    readonly property string iClearAll:  "delete_sweep"

    // volumen y micrófono
    readonly property string iVolHigh:  "volume_up"
    readonly property string iVolMed:   "volume_down"
    readonly property string iVolLow:   "volume_mute"
    readonly property string iVolOff:   "volume_off"
    readonly property string iMic:      "mic"
    readonly property string iMicOff:   "mic_off"

    // Utils surface
    readonly property string iCoffee:      "coffee"
    readonly property string iBrightness:  "brightness_7"
    readonly property string iGauge:       "speed"
    readonly property string iSettings2:   "settings"

    // Notificaciones — teclado / layout
    readonly property string iKeyboard:    "keyboard"
    readonly property string iLanguage:    "translate"

    // Connectivity surface
    readonly property string iBluetooth:     "bluetooth"
    readonly property string iBluetoothOff:  "bluetooth_disabled"
    readonly property string iLockOpen:      "lock_open"
    readonly property string iWifiOff:       "wifi_off"
    readonly property string iRefresh:       "refresh"
    readonly property string iCheck:         "check"
    readonly property string iPlus:          "add"
    readonly property string iMinus:         "remove"
    readonly property string iChevronRight:  "chevron_right"
    readonly property string iChevronLeft:   "chevron_left"
    readonly property string iPlay:          "play_arrow"
    readonly property string iPause:         "pause"

    /**
     * Retorna el icono de volumen según el nivel y mute.
     */
    function getVolumeIcon(volume, isMuted) {
        if (isMuted)          return iVolOff
        if (volume >= 0.66)   return iVolHigh
        if (volume >= 0.33)   return iVolMed
        if (volume > 0)       return iVolLow
        return iVolOff
    }

    /**
     * Retorna el icono de micrófono según nivel y mute.
     */
    function getMicVolumeIcon(volume, isMuted) {
        if (!isMuted && volume > 0) return iMic
        return iMicOff
    }

    /**
     * Retorna un icono Material Symbols para el summary+urgency dado.
     * Heurística por palabras clave (case-insensitive), como caelestia.
     */
    function getNotifIcon(summary, urgency) {
        var s = ("" + summary).toLowerCase()
        if (s.includes("reboot") || s.includes("restart") || s.includes("reinicia")) return iPower
        if (s.includes("record") || s.includes("grabando") || s.includes("captura")) return iRecord
        if (s.includes("battery") || s.includes("bater") || s.includes("energ")) return iBattery
        if (s.includes("capture") || s.includes("screenshot") || s.includes("captur") || s.includes("pantalla")) return iCamera
        if (s.includes("teclado") || s.includes("keyboard") || s.includes("layout") || s.includes("kbd") || s.includes("keymap") || s.includes("input")) return iKeyboard
        if (s.includes("language") || s.includes("idioma") || s.includes("español") || s.includes("espanol") || s.includes("inglés") || s.includes("ingles") || s.includes("english") || s.includes("spanish") || s.includes("translate")) return iLanguage
        if (s.includes("update") || s.includes("actualizaci") || s.includes("instal") || s.includes("upgrade")) return iUpdate
        if (s.includes("download") || s.includes("descarga")) return iDownload
        if (s.includes("mail") || s.includes("correo") || s.includes("email")) return iMail
        if (s.includes("calendar") || s.includes("calendario") || s.includes("event")) return iCalendar
        if (s.includes("message") || s.includes("chat") || s.includes("mensaje") || s.includes("whatsapp") || s.includes("telegram") || s.includes("discord")) return iChat
        if (s.includes("music") || s.includes("spotify") || s.includes("música") || s.includes("canción") || s.includes("cancion")) return iMusic
        if (s.includes("video") || s.includes("youtube") || s.includes("filme") || s.includes("película")) return iVideo
        if (s.includes("warning") || s.includes("error") || s.includes("alert") || s.includes("fallo") || s.includes("peligro")) return iWarning
        if (s.includes("lock") || s.includes("screen") || s.includes("pantalla") || s.includes("bloqueo")) return iLock
        if (s.includes("network") || s.includes("wifi") || s.includes("red") || s.includes("internet") || s.includes("conexi")) return iWifi
        if (s.includes("volume") || s.includes("audio") || s.includes("volumen") || s.includes("sonido")) return iVolume
        if (s.includes("file") || s.includes("archivo") || s.includes("folder") || s.includes("carpeta")) return iFile
        if (s.includes("time") || s.includes("tiempo") || s.includes("break") || s.includes("pausa") || s.includes("alarma")) return iClock
        if (s.includes("weather") || s.includes("clima") || s.includes("lluvia") || s.includes("sol")) return iWeather
        if (s.includes("person") || s.includes("user") || s.includes("usuario") || s.includes("profile") || s.includes("perfil")) return iPerson
        if (s.includes("setting") || s.includes("config") || s.includes("ajuste")) return iSettings
        if (s.includes("terminal") || s.includes("consola") || s.includes("shell")) return iTerminal
        // urgency override
        if (urgency === NotificationUrgency.Critical) return iWarning
        if (urgency === NotificationUrgency.Low) return iInfo
        // default: notification bell
        return iBell
    }
}
