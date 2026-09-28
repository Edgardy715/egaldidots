import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"
import "lockscreen"
import Quickshell.Services.Pam

ShellRoot {
    id: root

    settings.watchFiles: false

    readonly property bool preview: Quickshell.env("QS_LOCK_PREVIEW") === "1"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string username: Quickshell.env("USER") || "Usuario"

    property var palette: ({})
    property string wallpaper: ""
    property bool busy: false
    property bool waitingForResponse: false
    property bool authenticated: false
    property string pendingSecret: ""
    property string promptText: "Contraseña"
    property string errorText: ""

    function authenticate(secret: string): void {
        if (root.preview || !sessionLock.secure || root.authenticated || !secret || root.busy) return

        root.errorText = ""
        root.busy = true
        if (pam.active && root.waitingForResponse) {
            root.waitingForResponse = false
            pam.respond(secret)
            return
        }
        if (pam.active) return

        root.pendingSecret = secret
        pam.user = root.username
        if (!pam.start()) {
            root.pendingSecret = ""
            root.busy = false
            root.errorText = "No se pudo iniciar la autenticación"
        }
    }

    function authenticationFailed(message: string): void {
        root.pendingSecret = ""
        root.waitingForResponse = false
        root.busy = false
        root.promptText = "Contraseña"
        root.errorText = message || "Contraseña incorrecta. Inténtalo de nuevo."
    }

    function power(action: string): void {
        if (root.preview) return
        if (action === "suspend" || action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action])
    }

    FileView {
        id: paletteFile
        path: Config.walColorsFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(paletteFile.text())
                root.palette = data
                root.wallpaper = data.wallpaper || ""
            } catch (e) {
                root.palette = ({})
            }
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        user: root.username

        onResponseRequiredChanged: {
            if (!responseRequired) return
            if (root.pendingSecret.length > 0) {
                const secret = root.pendingSecret
                root.pendingSecret = ""
                respond(secret)
            } else {
                root.promptText = message || "Contraseña"
                root.waitingForResponse = true
                root.busy = false
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.pendingSecret = ""
                root.authenticated = true
                successTimer.start()
            } else if (result !== PamResult.Error || root.errorText.length === 0) {
                root.authenticationFailed("Contraseña incorrecta. Inténtalo de nuevo.")
            }
        }

        onError: error => root.authenticationFailed("No se pudo verificar la contraseña")
    }

    // Keep the Wayland lock held while the success feedback is visible.
    Timer {
        id: successTimer
        interval: Flags.reduceMotion ? 220 : Motion.standard + 2 * Motion.fast + Motion.morph + 80
        onTriggered: {
            if (!root.authenticated) return
            if (!root.preview) sessionLock.locked = false
            quitTimer.start()
        }
    }

    Timer {
        id: quitTimer
        interval: 220
        onTriggered: Qt.quit()
    }

    Timer {
        running: !root.preview && !root.authenticated && !sessionLock.secure
        interval: 4000
        onTriggered: {
            if (!sessionLock.secure) {
                console.error("Isla: no se pudo asegurar la sesión")
                Qt.exit(3)
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: !root.preview

        surface: Component {
            WlSessionLockSurface {
                color: "#090b11"

                LockSurface {
                    anchors.fill: parent
                    username: root.username
                    wallpaper: root.wallpaper
                    palette: root.palette
                    authenticated: root.authenticated
                    busy: root.busy
                    secured: sessionLock.secure
                    responseVisible: pam.responseVisible
                    promptText: root.promptText
                    errorText: root.errorText
                    onUnlockRequested: secret => root.authenticate(secret)
                    onPowerRequested: action => root.power(action)
                }
            }
        }
    }

    // Preview never acquires a Wayland session lock or starts PAM.
    Window {
        visible: root.preview
        width: Number(Quickshell.env("QS_LOCK_PREVIEW_WIDTH")) || 1440
        height: Number(Quickshell.env("QS_LOCK_PREVIEW_HEIGHT")) || 900
        title: "Isla · Vista previa del bloqueo"
        color: "#090b11"

        Loader {
            id: previewLoader
            anchors.fill: parent
            active: root.preview
            sourceComponent: Component {
                LockSurface {
                    username: root.username
                    wallpaper: root.wallpaper
                    palette: root.palette
                    preview: true
                    busy: false
                    secured: true
                    responseVisible: false
                    promptText: "Contraseña"
                    errorText: ""
                }
            }
        }

        Timer {
            running: root.preview && Quickshell.env("QS_LOCK_PREVIEW_SHOT") !== ""
            interval: Number(Quickshell.env("QS_LOCK_PREVIEW_DELAY")) || 1200
            onTriggered: {
                if (previewLoader.status !== Loader.Ready) return
                previewLoader.item.grabToImage(result => {
                    result.saveToFile(Quickshell.env("QS_LOCK_PREVIEW_SHOT"))
                    Qt.quit()
                })
            }
        }
    }
}
