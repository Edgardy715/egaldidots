import QtQuick

// Target dimensions only. The host owns animated width, height and radius.
QtObject {
    id: root
    property real s: 1
    property string surface: ""
    property bool launcherClosing: false
    property int launcherClosePhase: 0
    // La pill viaja como gota (launcher): círculo del alto de reposo.
    property bool dropMode: false
    property real restContentWidth: 0
    property real restLeftWidth: 0
    property real restRightWidth: 0
    property real restHeight: 38
    property var surfaceSizes: ({})
    property size fallbackSurface: Qt.size(320, 300)
    property size mediaSurface: IslandGeometry.mediaSurface
    property real marginMd: 0
    property real fontSizeBodyLg: 0
    property real fontSizeLabel: 0
    property real fontScale: 1

    property bool hasNotification: false
    property bool notifAnimating: false
    property string notifState: ""
    property real notifBreathRadius: 0

    property bool contentLoaded: false
    property real contentHeightHint: 0
    property bool contentClosing: false
    property bool resultsVisible: false
    property bool emptyResultsVisible: false
    property bool showCalculator: false
    property var resultsCount: 0
    property var maxVisibleResults: undefined
    property var albumDistinct: undefined
    property var album: undefined

    readonly property real coreH: restHeight * s
    readonly property real padH: 18 * s
    readonly property real notifCircleD: coreH * 0.55
    readonly property real notifPillW: 380 * s
    readonly property real notifPillH: 72 * s
    readonly property bool surfaceOpen: surface.length > 0
    // The router clears the surface before resetting the phase, but the host's
    // derived launcherClosing may drop first: reading the phase too keeps that
    // instant from targeting the open launcher (a 680 px blip that kicked the
    // returning pill outward).
    readonly property bool launcherLeaving: surface === "launcher"
        && (launcherClosing || launcherClosePhase !== 0)
    readonly property bool launcherReturning: launcherLeaving && launcherClosePhase === 2
    readonly property size sizeFor: surfaceOpen && surfaceSizes[surface]
        ? surfaceSizes[surface] : fallbackSurface
    readonly property real authInputW: 400 * s
    readonly property real launcherSearchH: (44 + marginMd * 2) * s
    readonly property real launcherHeaderH: 78 * s
    readonly property bool launcherHeaderVisible: surface === "launcher" && !launcherLeaving
    readonly property real restW: restContentWidth + padH * 2 + restLeftWidth + restRightWidth
        + (restLeftWidth > 0 ? 18 * s : 0) + (restRightWidth > 0 ? 18 * s : 0)

    readonly property real launcherH: {
        var sb = 44 * s
        var headerH = launcherHeaderH
        var padTop = 16 * s
        var padBot = 20 * s
        if (!contentLoaded) return headerH + sb + padTop + padBot
        if (contentClosing || !resultsVisible) {
            var calcH = showCalculator ? (44 * s + 10 * s) : 0
            return headerH + sb + padTop + padBot + calcH + (emptyResultsVisible ? 44 * s : 0)
        }
        var itemH = 72 * s
        var sp = 4 * s
        var count = Math.min(resultsCount || 0, maxVisibleResults || 6)
        var listH = count > 0 ? (itemH * count + sp * (count - 1)) : 0
        var dividerH = 1 * s
        var footerH = 34 * s
        var maxListH = sizeFor.height * s - headerH - sb - padTop - padBot - dividerH - footerH
        var cappedListH = Math.max(0, Math.min(maxListH, listH))
        return headerH + sb + padTop + padBot + (12 * s) + dividerH
            + cappedListH + footerH
    }
    readonly property real mediaH: {
        if (!contentLoaded) return mediaSurface.height * s
        var base = mediaSurface.height * s
        if (albumDistinct !== undefined
                ? albumDistinct
                : (album && album.length > 0)) base += 16 * s
        return base
    }

    readonly property real _notifTargetW: {
        if (!hasNotification) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return notifPillW
        if (notifAnimating && notifState === "return") return Math.max(restW, 120 * s + padH * 2)
        return NaN
    }
    readonly property real _notifTargetH: {
        if (!hasNotification) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return notifPillH
        if (notifAnimating && notifState === "return") return coreH
        return NaN
    }
    readonly property real _notifTargetRadius: {
        if (!hasNotification) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD / 2
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return Math.min(18 * s, notifPillH / 2 - 2 * s) + notifBreathRadius
        if (notifAnimating && notifState === "return") return coreH / 2
        return NaN
    }

    readonly property real dropD: coreH
    readonly property real targetW: dropMode ? dropD
        : hasNotification && notifAnimating && !isNaN(_notifTargetW) ? _notifTargetW
        : surfaceTargetW
    // The surface's own size, without a notification borrowing the glass.
    // The launcher card only ever opens at its landing and leaves as a drop
    // (LauncherDropMotion); once the drop is back at the top — or never left it,
    // when the launcher is closed mid-gather — every closing phase targets rest.
    // The old in-place search bar here flashed a 660 px slab under the screen edge.
    readonly property real surfaceTargetW: launcherLeaving ? restW
        : surface === "auth" ? restContentWidth + authInputW + 56 * s
        : surfaceOpen ? sizeFor.width * s : restW
    readonly property real targetH: dropMode ? dropD
        : hasNotification && notifAnimating && !isNaN(_notifTargetH) ? _notifTargetH
        : surfaceTargetH
    readonly property real surfaceTargetH: {
        if (launcherLeaving) return coreH
        if (!surfaceOpen) return coreH
        if (surface === "auth") return Math.max(82, Math.max(44, fontSizeBodyLg + fontScale + 20)
            + 3 + Math.max(18, fontSizeLabel + 6) + 16) * s
        if (surface === "launcher") return launcherH
        if (surface === "media") return mediaH
        // A surface that measures itself only gives back room it does not use.
        if (contentLoaded && contentHeightHint > 0) return Math.min(sizeFor.height * s, contentHeightHint)
        return sizeFor.height * s
    }
    readonly property real radiusRest: coreH / 2
    readonly property real radiusOpen: Math.min(Math.max(18 * s, targetW * 0.055), Math.max(2, targetH / 2 - 2 * s))
    readonly property real targetRadius: dropMode ? dropD / 2
        : hasNotification && notifAnimating && !isNaN(_notifTargetRadius) ? _notifTargetRadius
        : launcherLeaving ? radiusRest
        : surface === "launcher" && targetH <= launcherSearchH ? targetH / 2
        : surface === "auth" ? targetH / 2 : surfaceOpen ? radiusOpen : radiusRest
}
