import QtQuick
import "../"
import "../Singletons"

// Rest status and launcher header; desktop integration stays in Pill.
Item {
    id: root
    property real s: 1
    property real coreH: 38
    property bool layoutChanging: false
    readonly property real restOpacity: restContent.opacity
    property real restWidth: 0
    property real restLeftWidth: 0
    property real restRightWidth: 0
    property string surface: ""
    property bool surfaceOpen: false
    property bool launcherReturning: false
    property bool launcherHeaderVisible: false
    property real launcherHeaderH: 78
    property real surfaceReveal: 1
    property real morphCloseness: 1
    property real restReturn: 1
    // Growth reveal of the open surface (morph.contentProgress).
    property real contentReveal: 1
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
    property string activityText: ""
    property string recordingPhase: ""
    property int recordingCountdown: 0

    function flashWorkspace(number) { restStatus.flashWorkspace(number) }
    function showVolume(progress, muted) { restStatus.showVolume(progress, muted) }
    function showMic(progress, muted) { restStatus.showMic(progress, muted) }
    function showBrightness(progress) { restStatus.showBrightness(progress) }
    function showBattery(percent, status) { restStatus.showBattery(percent, status) }

    // El reloj permanece como único contenido de reposo de la pill.
    Row {
        id: restContent
        height: root.coreH
        // The launcher clock rides the glass to its header slot: clamped to the
        // geometry it never sits below a pill that is still rest-sized, nor
        // under the music ring while the pill is still narrow.
        readonly property real restX: root.restLeftWidth > 0 || root.restRightWidth > 0
            ? 18 * root.s + root.restLeftWidth + (root.restLeftWidth > 0 ? 18 * root.s : 0)
            : (parent.width - implicitWidth) / 2
        // Leaving for a surface it fades where it sat, in the top row, rather
        // than sliding to the middle of the growing glass.
        // Held through the first close phase too: the header slot then follows the
        // glass shrinking to the search row instead of jumping to the top row.
        readonly property bool inLauncher: root.surface === "launcher" && !root.launcherReturning
        y: inLauncher
            ? Math.min((root.launcherHeaderH - height) / 2, (parent.height - height) / 2)
            : root.surface === "auth" ? (parent.height - height) / 2
            : root.surface !== "" ? Math.min((parent.height - height) / 2, (root.coreH - height) / 2)
            : (parent.height - height) / 2
        x: root.surface === "auth" ? 18 * root.s
            : inLauncher && root.hasMedia
                // Side modules put the rest slot far from the right edge: travel with the growth.
                ? restX + (Math.max(restX, parent.width - implicitWidth - 26 * root.s) - restX)
                    * (root.restLeftWidth > 0 || root.restRightWidth > 0 ? root.contentReveal : 1)
                : restX
        // spacing 0 a propósito: el gap wsFlash↔reloj vive DENTRO del chip
        // (chipW, que anima y arrastra el ancho de la pill vía este implicitWidth). Un
        // spacing >0 haría que el Row sumara el gap al instante al flipear
        // wsFlash.visible (opacity>0.01) — layout del Row NO se anima → el
        // reloj saltaría ~7px al abrir/cerrar el flash (tirón). Con spacing 0
        // el reloj se desliza PURAMENTE siguiendo el width animado del chip.
        spacing: 0
        z: 3
        // Where the fade is heading, not the fade's lag.
        // Un cambio de ancho del propio reposo (chip de volumen, espacio) no es un
        // retorno de surface: el contenido se queda y sólo el ancho se desliza.
        readonly property bool restResizing: !root.surfaceOpen && !root.launcherReturning
            && !root.hasNotification && !root.notifAnimating
            && root.height <= root.coreH + 1.5 * root.s
            && Math.abs(root.width - root.restWidth) < 120 * root.s
        readonly property real targetOpacity: root.layoutChanging ? 0 : root.launcherHeaderVisible ? 1 : root.surface === "auth" ? 1
            : ((root.surfaceOpen && !root.launcherReturning) || (root.hasNotification && root.notifAnimating)) ? 0
            : restResizing ? 1
            : root.restReturn
                * Math.max(0, Math.min(1, (root.width - root.restWidth + 9 * root.s) / (8 * root.s)))
        opacity: targetOpacity
        // Vuelve al reposo creciendo desde 0.96, atado al mismo fundido de opacidad.
        scale: Flags.reduceMotion ? 1 : Motion.restScale + (1 - Motion.restScale) * opacity
        visible: opacity > 0.01
        enabled: !root.layoutChanging
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Math.round(Motion.fast * 0.7); easing.type: Motion.easeStandard } }

        IslandRestStatus {
            id: restStatus
            s: root.s
            coreH: root.coreH
            capsLockOn: root.capsLockOn
            now: root.now
            activityText: root.activityText
            recordingPhase: root.recordingPhase
            recordingCountdown: root.recordingCountdown
            onRequestCalendar: root.requestCalendar()
        }
    }

    Row {
        x: 26 * root.s
        y: (root.launcherHeaderH - height) / 2
        height: 42 * root.s
        spacing: 12 * root.s
        // Waits for the glass to make room instead of landing on the clock.
        opacity: root.launcherHeaderVisible && root.hasMedia ? root.surfaceReveal * root.contentReveal : 0
        visible: opacity > 0.01
        // Growth already paces the reveal; easing on top would trail the glass.
        Behavior on opacity { enabled: root.contentReveal >= 1; Anim { type: Anim.DefaultEffects } }

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
        opacity: root.launcherHeaderVisible ? 0.72 * root.contentReveal : 0
        visible: opacity > 0.01
        z: 2
        Behavior on opacity { enabled: root.contentReveal >= 1; Anim { type: Anim.DefaultEffects } }
    }

}
