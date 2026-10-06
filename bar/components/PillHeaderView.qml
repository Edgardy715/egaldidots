import QtQuick
import "../"
import "../Singletons"

// Rest status and launcher header; desktop integration stays in Pill.
Item {
    id: root
    property real s: 1
    property real coreH: 38
    property string surface: ""
    property bool surfaceOpen: false
    property bool launcherReturning: false
    property bool launcherHeaderVisible: false
    property real launcherHeaderH: 78
    property real surfaceReveal: 1
    property real morphCloseness: 1
    property bool hasNotification: false
    property bool notifAnimating: false
    property bool capsLockOn: false
    property date now: new Date()
    property bool hasMedia: false
    property string artUrl: ""
    property bool hasProgress: false
    property real progress: 0
    property string title: ""
    property string artist: ""
    readonly property real restContentWidth: restContent.implicitWidth
    readonly property bool workspaceAnimating: restStatus.workspaceAnimating
    signal requestCalendar()

    function flashWorkspace(number) { restStatus.flashWorkspace(number) }
    function showVolume(progress, muted) { restStatus.showVolume(progress, muted) }
    function showMic(progress, muted) { restStatus.showMic(progress, muted) }
    function showBrightness(progress) { restStatus.showBrightness(progress) }
    function showBattery(percent, status) { restStatus.showBattery(percent, status) }

    // El reloj permanece como único contenido de reposo de la pill.
    Row {
        id: restContent
        height: root.coreH
        y: root.launcherHeaderVisible
            ? (root.launcherHeaderH - height) / 2
            : (parent.height - height) / 2
        x: root.surface === "auth" ? 18 * root.s
            : root.launcherHeaderVisible && root.hasMedia
                ? parent.width - implicitWidth - 26 * root.s
                : (parent.width - implicitWidth) / 2
        // spacing 0 a propósito: el gap wsFlash↔reloj vive DENTRO del chip
        // (chipW, que anima y arrastra el ancho de la pill vía este implicitWidth). Un
        // spacing >0 haría que el Row sumara el gap al instante al flipear
        // wsFlash.visible (opacity>0.01) — layout del Row NO se anima → el
        // reloj saltaría ~7px al abrir/cerrar el flash (tirón). Con spacing 0
        // el reloj se desliza PURAMENTE siguiendo el width animado del chip.
        spacing: 0
        z: 3
        opacity: root.launcherHeaderVisible ? 1 : root.surface === "auth" ? 1
            : ((root.surfaceOpen && !root.launcherReturning) || (root.hasNotification && root.notifAnimating)) ? 0
            : Math.pow(root.morphCloseness, 1.2)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.surfaceOpen ? Motion.fast : Motion.standard; easing.type: Motion.easeStandard } }

        IslandRestStatus {
            id: restStatus
            s: root.s
            coreH: root.coreH
            capsLockOn: root.capsLockOn
            now: root.now
            onRequestCalendar: root.requestCalendar()
        }
    }

    Row {
        x: 26 * root.s
        y: (root.launcherHeaderH - height) / 2
        height: 42 * root.s
        spacing: 12 * root.s
        opacity: root.launcherHeaderVisible && root.hasMedia ? root.surfaceReveal : 0
        visible: opacity > 0.01
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        IslandMediaSummary {
            s: root.s
            coverDiameter: 42 * root.s
            textWidth: Math.max(0, root.width - restContent.implicitWidth - 126 * root.s)
            spacing: 12 * root.s
            metadataSpacing: 3 * root.s
            titlePixelSize: Theme.fontSizeBodyLg * root.s
            artistPixelSize: Theme.fontSizeBody * root.s
            artUrl: root.artUrl
            hasProgress: root.hasProgress
            progress: root.progress
            title: root.title
            artist: root.artist
            showArtist: artist.length > 0
        }
    }

    // El divisor conserva el reloj como cabecera del launcher.
    Rectangle {
        id: launcherHeaderDivider
        x: 22 * root.s
        y: root.launcherHeaderH
        width: Math.max(0, parent.width - 44 * root.s)
        height: 1 * root.s
        color: Theme.sheen
        opacity: root.launcherHeaderVisible ? 0.72 : 0
        visible: opacity > 0.01
        z: 2
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
    }

}
