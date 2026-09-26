pragma Singleton
import QtQuick
import Quickshell

/** Base geometry for the island. Values are unscaled; consumers apply their s. */
Singleton {
    readonly property real restHeight: 38
    readonly property size fallbackSurface: Qt.size(320, 300)

    readonly property size mixerSurface: Qt.size(340, 380)
    readonly property size mediaSurface: Qt.size(640, 300)
    readonly property size calendarSurface: Qt.size(340, 420)
    readonly property size workspacesSurface: Qt.size(360, 200)
    readonly property size notificationsSurface: Qt.size(380, 540)
    readonly property size wallpaperSurface: Qt.size(1000, 640)
    readonly property size launcherSurface: Qt.size(680, 620)
    readonly property size utilitiesSurface: Qt.size(360, 420)
    readonly property size sessionSurface: Qt.size(540, 304)
    readonly property size authSurface: Qt.size(0, 0)
    readonly property size overviewSurface: Qt.size(1000, 340)
    readonly property size connectivitySurface: Qt.size(360, 480)
    readonly property size clipboardSurface: Qt.size(580, 480)

    readonly property var surfaceSizes: ({
        mixer: mixerSurface,
        media: mediaSurface,
        calendar: calendarSurface,
        workspaces: workspacesSurface,
        notifs: notificationsSurface,
        wallpaper: wallpaperSurface,
        launcher: launcherSurface,
        utils: utilitiesSurface,
        session: sessionSurface,
        auth: authSurface,
        overview: overviewSurface,
        connectivity: connectivitySurface,
        clipboard: clipboardSurface
    })
}
