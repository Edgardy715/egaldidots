import QtQuick

// Target dimensions only. The host owns animated width, height and radius.
QtObject {
    id: root
    property real s: 1
    property string surface: ""
    property bool launcherClosing: false
    property int launcherClosePhase: 0
    property real restContentWidth: 0
    property real restHeight: 38
    property var surfaceSizes: ({})
    property size fallbackSurface: Qt.size(320, 300)
    property size mediaSurface: Qt.size(640, 300)
    property real marginMd: 0
    property real fontSizeBodyLg: 0
    property real fontSizeLabel: 0
    property real fontScale: 1

    property bool hasNotification: false
    property bool notifAnimating: false
    property string notifState: ""
    property real notifBreathRadius: 0

    property bool contentLoaded: false
    property bool contentClosing: false
    property bool resultsVisible: false
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
    readonly property bool launcherReturning: surface === "launcher"
        && launcherClosing && launcherClosePhase === 2
    readonly property size sizeFor: surfaceOpen && surfaceSizes[surface]
        ? surfaceSizes[surface] : fallbackSurface
    readonly property real authInputW: 400 * s
    readonly property real launcherSearchH: (44 + marginMd * 2) * s
    readonly property real launcherHeaderH: 78 * s
    readonly property bool launcherHeaderVisible: surface === "launcher" && !launcherClosing
    readonly property real restW: restContentWidth + padH * 2

    readonly property real launcherH: {
        var sb = 44 * s
        var headerH = launcherHeaderH
        var padTop = 16 * s
        var padBot = 20 * s
        if (!contentLoaded) return headerH + sb + padTop + padBot
        if (contentClosing || !resultsVisible) {
            var calcH = showCalculator ? (44 * s + 10 * s) : 0
            return headerH + sb + padTop + padBot + calcH
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
        if (notifAnimating && notifState === "return") return Math.max(restContentWidth, 120 * s) + padH * 2
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

    readonly property real targetW: hasNotification && notifAnimating && !isNaN(_notifTargetW) ? _notifTargetW
        : launcherReturning ? restW
        : surface === "auth" ? restContentWidth + authInputW + 56 * s
        : surfaceOpen ? sizeFor.width * s : restW
    readonly property real targetH: {
        if (hasNotification && notifAnimating && !isNaN(_notifTargetH)) return _notifTargetH
        if (launcherReturning) return coreH
        if (surface === "launcher" && launcherClosing) return launcherSearchH
        if (!surfaceOpen) return coreH
        if (surface === "auth") return Math.max(82, Math.max(44, fontSizeBodyLg + fontScale + 20)
            + 3 + Math.max(18, fontSizeLabel + 6) + 16) * s
        if (surface === "launcher") return launcherH
        if (surface === "media") return mediaH
        return sizeFor.height * s
    }
    readonly property real radiusRest: coreH / 2
    readonly property real radiusOpen: Math.min(Math.max(18 * s, targetW * 0.055), Math.max(2, targetH / 2 - 2 * s))
    readonly property real targetRadius: hasNotification && notifAnimating && !isNaN(_notifTargetRadius) ? _notifTargetRadius
        : launcherReturning ? radiusRest
        : surface === "launcher" && targetH <= launcherSearchH ? targetH / 2
        : surface === "auth" ? targetH / 2 : surfaceOpen ? radiusOpen : radiusRest
}
