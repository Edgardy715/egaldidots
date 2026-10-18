import QtQuick
import Quickshell.Widgets
import "../"
import "../Singletons"
import "."

Item {
    id: root
    property real s: 1
    property bool open: false
    property bool closing: false
    property var wallpaperModel: null
    property bool applying: false
    property string applyPhase: ""
    property bool scanning: false
    property string applyError: ""
    property string feedback: ""
    property color previewAccent: "white"
    property bool mediaHas: false
    property string mediaArtUrl: ""
    property bool mediaHasProgress: false
    property real mediaProgress: 0
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool navigating: false
    property bool footerEntered: false
    property real wheelTravel: 0
    property url previousPreview: ""
    property url readyPreview: ""
    property url previewSource: ""
    readonly property url desiredPreview: sel ? "file://" + sel.path.split("/").map(encodeURIComponent).join("/") + "?v=" + (sel.cacheRevision || 0) : ""
    function updatePreview() {
        if (active && !heroReveal.running && previewSource !== desiredPreview) previewSource = desiredPreview
    }
    onDesiredPreviewChanged: Qt.callLater(root.updatePreview)
    readonly property int count: wallpaperModel ? wallpaperModel.count : 0
    readonly property bool active: open && !closing
    readonly property bool compact: width < 720 * s || Flags.fontScale > 1.25
    property var sel: null
    function refreshSelection() {
        if (!wallpaperModel || wallpaperModel.count === 0) { sel = null; return }
        const item = wallpaperModel.get(Math.max(0, Math.min(pathView.currentIndex, wallpaperModel.count - 1)))
        sel = {path: item.path, baseName: item.baseName, thumbSource: item.thumbSource,
               applied: item.applied, cacheRevision: item.cacheRevision}
    }
    onWallpaperModelChanged: Qt.callLater(root.refreshSelection)
    onCountChanged: Qt.callLater(root.refreshSelection)
    Connections {
        target: root.wallpaperModel
        function onDataChanged() { Qt.callLater(root.refreshSelection) }
    }
    readonly property string selName: sel ? displayName(sel.baseName || "") : ""
    readonly property bool selApplied: sel ? sel.applied === true : false
    function linearChannel(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4) }
    readonly property real previewLuminance: 0.2126 * linearChannel(previewAccent.r) + 0.7152 * linearChannel(previewAccent.g) + 0.0722 * linearChannel(previewAccent.b)
    readonly property color onPreviewAccent: previewLuminance > 0.179 ? "#000000" : "#ffffff"
    readonly property int currentIndex: pathView.currentIndex
    signal requestClose()
    signal selectionChanged(int index)
    signal commitRequested(int index)
    signal applyPathRequested(string path)
    signal refreshRequested()
    signal thumbnailRequested(string path, string thumb)
    function displayName(name) {
        if (name.startsWith("wallhaven-")) return "Wallhaven  ·  " + name.slice(10).toUpperCase()
        return name.replace(/[_-]+/g, " ")
    }
    function selectIndex(index) {
        if (!active || !wallpaperModel || wallpaperModel.count === 0 || applying) return
        closeTimer.stop()
        navigating = true
        navigateTimer.restart()
        pathView.currentIndex = ((index % wallpaperModel.count) + wallpaperModel.count) % wallpaperModel.count
    }
    function cycle(dir) { selectIndex(pathView.currentIndex + dir) }
    function goIndex(num) {
        if (!wallpaperModel || wallpaperModel.count === 0) return
        var idx = num === 0 ? 9 : num - 1
        if (idx >= 0 && idx < wallpaperModel.count) selectIndex(idx)
    }
    function commitSelection() { if (active && count > 0 && !applying && (!selApplied || feedback === "error")) commitRequested(pathView.currentIndex) }
    function applyPath(path) { applyPathRequested(path) }
    function applied() { if (active) closeTimer.restart() }
    onActiveChanged: {
        closeTimer.stop()
        wheelTravel = 0
        if (active) { navigating = false; footerEntered = false; updatePreview() }
        else { navigateTimer.stop(); navigating = false; heroReveal.complete() }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) heroReveal.complete()
        }
    }
    Timer { id: navigateTimer; interval: 2000; onTriggered: root.navigating = false }
    Timer {
        interval: Motion.stagger(6)
        running: root.active && !root.footerEntered
        onTriggered: root.footerEntered = true
    }
    Timer {
        id: closeTimer
        interval: Math.max(900, Math.round(1100 * Motion.mult))
        onTriggered: if (root.active) root.requestClose()
    }
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 72 * s
        z: 10
        opacity: root.footerEntered ? 1 : 0

        Rectangle {
            x: 23 * s
            y: 19 * s
            width: 34 * s
            height: width
            radius: Theme.radiusLg * s
            color: Qt.alpha(root.previewAccent, 0.18)
            border.color: Qt.alpha(root.previewAccent, 0.4)

            MaterialIcon {
                anchors.centerIn: parent
                iconName: "wallpaper"
                color: root.previewAccent
                font.pixelSize: 20 * s
            }

        }

        Column {
            x: 68 * s
            y: 16 * s
            width: Math.min(root.mediaHas && root.width > 1000 * root.s && !root.compact ? 300 * root.s : root.width, Math.max(0, refreshButton.x - x - 78 * root.s))
            spacing: 3 * s

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: qsTr("Fondos de pantalla")
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeHead * s
                font.weight: Font.DemiBold
            }

            Text {
                text: qsTr("%1 fondos disponibles").arg(root.count)
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * s
            }

        }

        Rectangle {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 22 * s
            y: 18 * s
            width: 36 * s
            height: width
            radius: Theme.radiusSm * s
            color: closeMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.13) : Qt.alpha(Theme.foreground, 0.06)

            MotionArea {
                id: closeMouse
                accessibleName: qsTr("Cerrar")

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestClose()
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.fast
                }

            }

            MaterialIcon {
                compressWithControl: true
                interaction: closeMouse.motion
                hovered: closeMouse.containsMouse
                anchors.centerIn: parent
                iconName: "close"
                color: Theme.foreground
                font.pixelSize: 18 * s
            }

        }

        Rectangle {
            id: refreshButton

            anchors.right: closeButton.left
            anchors.rightMargin: 8 * s
            y: 18 * s
            width: 36 * s
            height: width
            radius: Theme.radiusSm * s
            color: refreshMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.13) : Qt.alpha(Theme.foreground, 0.06)

            MotionArea {
                id: refreshMouse
                accessibleName: qsTr("Actualizar fondos")

                anchors.fill: parent
                enabled: root.active && !root.applying
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshRequested()
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.fast
                }

            }

            MaterialIcon {
                compressWithControl: true
                interaction: refreshMouse.motion
                hovered: refreshMouse.containsMouse
                anchors.centerIn: parent
                iconName: "refresh"
                color: Theme.foreground
                font.pixelSize: 18 * s

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.scanning && root.active && !Flags.reduceMotion
                }

            }

        }

        Row {
            anchors.right: refreshButton.left
            anchors.rightMargin: 116 * root.s
            anchors.verticalCenter: refreshButton.verticalCenter
            spacing: 10 * root.s
            visible: root.mediaHas && root.width > 1000 * root.s && !root.compact

            IslandMediaSummary {
                s: root.s
                coverDiameter: 32 * root.s
                textWidth: 200 * root.s
                spacing: 10 * root.s
                metadataSpacing: 2 * root.s
                titlePixelSize: 12.5 * root.s
                artistPixelSize: 11 * root.s
                artUrl: root.mediaArtUrl
                hasProgress: root.mediaHasProgress
                progress: hasProgress ? Math.max(0, Math.min(1,
                    root.mediaProgress)) : 0
                title: root.mediaTitle
                artist: root.mediaArtist
            }
        }

        Text {
            anchors.right: refreshButton.left
            anchors.rightMargin: 16 * s
            anchors.verticalCenter: refreshButton.verticalCenter
            text: root.count > 0 ? (pathView.currentIndex + 1) + " / " + root.count : "—"
            color: root.previewAccent
            font.family: Theme.fontMono
            font.pixelSize: 12 * s
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }

        }

    }

    Item {
        id: shelf
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 12 * root.s
        visible: root.count > 0

        Item {
            id: previewArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: pathView.top
            anchors.bottomMargin: 18 * root.s

            ClippingRectangle {
                id: preview
                objectName: "wallpaperPreview"
                anchors.centerIn: parent
                height: Math.max(0, parent.height)
                width: Math.min(parent.width, height * 16 / 9)
                radius: 16 * root.s
                color: Qt.alpha(Theme.background, 0.5)
                border.width: Theme.borderHairline
                border.color: Qt.alpha(Theme.foreground, 0.18)

                Image {
                    anchors.fill: parent
                    objectName: "previewThumbnail"
                    source: root.sel ? root.sel.thumbSource : ""
                    opacity: heroImage.status === Image.Error ? 1 : root.previousPreview.toString().length > 0 ? 0 : 1 - heroImage.opacity
                    sourceSize: Qt.size(960, 540)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Image {
                    anchors.fill: parent
                    objectName: "previousPreview"
                    source: root.previousPreview
                    opacity: heroImage.status === Image.Error ? 0 : 1 - heroImage.opacity
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Image {
                    id: heroImage
                    objectName: "heroImage"
                    anchors.fill: parent
                    source: root.previewSource
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    opacity: 0
                    function revealReady() {
                        if (status !== Image.Ready || heroReveal.running || opacity === 1) return
                        heroReveal.restart()
                    }
                    onSourceChanged: {
                        root.previousPreview = root.readyPreview
                        heroReveal.stop()
                        opacity = 0
                        Qt.callLater(revealReady)
                    }
                    onStatusChanged: if (status === Image.Ready) Qt.callLater(revealReady)
                    NumberAnimation {
                        id: heroReveal
                        target: heroImage
                        property: "opacity"
                        from: 0; to: 1
                        duration: Flags.reduceMotion ? 0 : Motion.standard
                        easing.type: Easing.InOutQuad
                        onFinished: {
                            if (heroImage.status === Image.Ready) root.readyPreview = heroImage.source
                            Qt.callLater(root.updatePreview)
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    z: 2
                    color: Theme.background
                    opacity: root.active && (root.applying || root.feedback === "done" || root.feedback === "error") ? 0.86 : 0
                    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardSmall; easing.type: Motion.easeStandard } }
                }
                WallpaperApplyFeedback {
                    objectName: "wallpaperInlineConfirmation"
                    anchors.centerIn: parent
                    z: 3
                    s: root.s
                    phase: !root.active ? "" : root.applying ? (root.applyPhase || "preparing") : root.feedback === "done" ? "done" : root.feedback === "error" ? "error" : ""
                    errorText: root.applyError
                    allowed: root.active
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 14 * root.s
                    width: currentLabel.implicitWidth + 24 * root.s
                    height: 28 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.background, 0.82)
                    visible: root.selApplied
                    Text {
                        id: currentLabel
                        anchors.centerIn: parent
                        text: qsTr("Fondo actual")
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: heroImage.status === Image.Error
                    iconName: "broken_image"
                    color: Theme.iconSecondary
                    font.pixelSize: 30 * root.s
                }
            }
        }

        Repeater {
            model: ["chevron_left", "chevron_right"]
            delegate: Rectangle {
                required property int index
                required property string modelData
                x: index === 0 ? pathView.x - 46 * root.s : pathView.x + pathView.width + 10 * root.s
                anchors.verticalCenter: pathView.verticalCenter
                width: 36 * root.s; height: 44 * root.s
                radius: Theme.radiusLg * root.s
                color: Qt.alpha(Theme.foreground, railMouse.containsMouse ? 0.11 : 0.04)
                opacity: railMouse.enabled ? 1 : 0.4
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: modelData
                    interaction: railMouse.motion
                    hovered: railMouse.containsMouse
                    color: Theme.foreground
                    font.pixelSize: 24 * root.s
                }
                MotionArea {
                    id: railMouse
                    anchors.fill: parent
                    accessibleName: index === 0 ? qsTr("Fondo anterior") : qsTr("Fondo siguiente")
                    enabled: root.active && !root.applying && root.count > 1
                    onClicked: root.cycle(index === 0 ? -1 : 1)
                }
            }
        }

        ListView {
            id: pathView
            objectName: "wallpaperThumbnails"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.min(Math.max(0, parent.width - 92 * root.s), root.count * 112 * root.s + Math.max(0, root.count - 1) * spacing)
            height: 82 * root.s
            orientation: ListView.Horizontal
            spacing: 10 * root.s
            model: root.wallpaperModel
            clip: true
            interactive: !root.applying
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 56 * root.s
            preferredHighlightEnd: width / 2 + 56 * root.s
            highlightMoveDuration: Flags.reduceMotion ? 0 : Motion.standard
            highlightResizeDuration: 0
            cacheBuffer: 320 * root.s
            highlight: Item {
                z: 2
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Flags.reduceMotion ? 0 : -3 * root.s
                    width: parent.width; height: 63 * root.s
                    radius: 8 * root.s
                    color: "transparent"
                    border.width: 2 * root.s
                    border.color: root.previewAccent
                }
            }
            onCurrentIndexChanged: { Qt.callLater(root.refreshSelection); root.selectionChanged(currentIndex) }

            delegate: Item {
                id: thumbnail
                objectName: "wallpaperThumbnail"
                required property int index
                required property string thumbSource
                required property string path
                required property string thumb
                required property bool thumbReady
                required property bool applied
                required property bool thumbFailed
                readonly property bool selected: ListView.isCurrentItem
                Component.onCompleted: {
                    if (!thumbReady && !thumbFailed) root.thumbnailRequested(path, thumb)
                }
                width: 112 * root.s
                height: pathView.height
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 63 * root.s
                    transform: Translate {
                        y: Flags.reduceMotion ? 0 : thumbnail.selected ? -3 * root.s : -Motion.iconLift * thumbMouse.motion.presence
                        Behavior on y { enabled: root.active && !Flags.reduceMotion; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
                    }
                    scale: thumbMouse.motion.visualScale
                    radius: 8 * root.s
                    color: Theme.cardBot
                    border.width: Theme.borderHairline
                    border.color: Theme.border
                    opacity: thumbnail.selected || thumbMouse.containsMouse ? 1 : 0.86
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3 * root.s
                        objectName: "wallpaperThumbnailImage"
                        source: thumbnail.thumbSource
                        sourceSize: Qt.size(192, 108)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.margins: 5 * root.s
                        width: 18 * root.s; height: width; radius: width / 2
                        color: Theme.background
                        visible: thumbnail.applied
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: Icons.iCheck
                            color: Theme.foreground
                            font.pixelSize: 13 * root.s
                        }
                    }
                    MaterialIcon {
                        interaction: thumbMouse.motion
                        hovered: thumbMouse.containsMouse
                        scale: thumbMouse.motion.visualScale
                        anchors.centerIn: parent
                        visible: thumbnail.thumbFailed
                        iconName: "broken_image"
                        color: Theme.iconSecondary
                        font.pixelSize: 18 * root.s
                    }

                }
                MotionArea {
                    id: thumbMouse
                    accessibleName: qsTr("Seleccionar fondo %1: %2").arg(thumbnail.index + 1).arg(root.displayName(thumbnail.path.split("/").pop()))
                    focusOnTab: false
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.active && !root.applying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectIndex(thumbnail.index)
                    onDoubleClicked: if (!thumbnail.applied || root.feedback === "error") root.applyPath(thumbnail.path)
                }
            }
        }

        MouseArea {
            anchors.fill: previewArea
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                root.wheelTravel += delta
                if (Math.abs(root.wheelTravel) >= (wheel.angleDelta.y !== 0 ? 90 : 32)) {
                    root.cycle(root.wheelTravel > 0 ? -1 : 1)
                    root.wheelTravel = 0
                }
                wheel.accepted = true
            }
        }
    }

    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: (root.compact ? 104 + 36 * Flags.fontScale : 98) * s
        visible: root.count > 0
        opacity: root.footerEntered ? 1 : 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.sheen
        }

        Column {
            x: 26 * s
            y: 14 * s
            width: Math.max(1, root.compact ? footer.width - 52 * s : applyActions.x - x - 24 * s)
            spacing: 5 * s

            Text {
                width: parent.width
                text: root.selName
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeHeadline * s
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }

            Text {
                width: parent.width
                text: root.feedback === "applying" ? "Cambiando fondo y colores…" : root.feedback === "done" ? "Fondo y colores actualizados" : root.feedback === "error" ? root.applyError : root.selApplied ? "Fondo actual  ·  ← → para explorar" : "← → navegar  ·  Intro o doble clic para aplicar"
                color: root.feedback === "error" ? Theme.error : root.feedback === "done" ? root.previewAccent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * s
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

        }

        Row {
            id: applyActions
            anchors.right: parent.right
            anchors.rightMargin: 24 * s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (root.compact ? 12 : 29) * root.s
            spacing: 8 * s

            Rectangle {
                width: Math.max(164 * root.s, applyLabel.implicitWidth + 58 * root.s)
                height: 40 * root.s
                radius: Theme.radiusLg * root.s
                color: applyMouse.pressed ? Qt.darker(root.previewAccent, 1.1) : applyMouse.containsMouse ? Qt.lighter(root.previewAccent, 1.1) : root.previewAccent
                opacity: applyMouse.enabled ? 1 : 0.65

                MotionArea {
                    id: applyMouse
                    accessibleName: qsTr("Aplicar fondo")

                    anchors.fill: parent
                    enabled: root.active && !root.applying && root.feedback !== "done" && (!root.selApplied || root.feedback === "error")
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.commitSelection()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.fast
                    }

                }

                Row {
                    anchors.centerIn: parent
                    spacing: 7 * root.s

                    MaterialIcon {
                        compressWithControl: true
                        interaction: applyMouse.motion
                        anchors.verticalCenter: parent.verticalCenter
                        hovered: applyMouse.containsMouse
                        iconName: root.feedback === "done" ? Icons.iCheck : root.applying ? "progress_activity" : "wallpaper"
                        color: root.onPreviewAccent
                        font.pixelSize: 18 * root.s

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 850
                            loops: Animation.Infinite
                            running: root.applying && root.active && !Flags.reduceMotion
                        }

                    }

                    Text {
                        scale: applyMouse.motion.visualScale
                        transform: Translate { y: -Motion.labelTravel * applyMouse.motion.presence }
                        anchors.verticalCenter: parent.verticalCenter
                        id: applyLabel
                        text: root.feedback === "done" ? "Listo" : root.applying ? "Aplicando…" : root.feedback === "error" ? "Reintentar" : root.selApplied ? "Fondo actual" : "Aplicar fondo"
                        color: root.onPreviewAccent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                        font.weight: Font.DemiBold
                    }

                }

            }

        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }

        }

    }

    // ══════════════ EMPTY / SCANNING ══════════════
    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingLg * s
        visible: root.count === 0

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56 * s
            height: 56 * s
            radius: Theme.radiusFull * s
            color: Qt.alpha(Theme.foreground, Theme.alphaGhost)
            border.width: Theme.borderHairline
            border.color: Theme.border

            MaterialIcon {
                anchors.centerIn: parent
                iconName: "wallpaper"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeHero * s
            }

            SequentialAnimation on opacity {
                running: root.scanning && root.active && !Flags.reduceMotion
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0.35
                    to: 1
                    duration: 1200
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 1
                    to: 0.35
                    duration: 1200
                    easing.type: Easing.InOutSine
                }

            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.scanning ? "Escaneando fondos…" : "Sin fondos"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.hBody * s
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.scanning
            text: qsTr("Añade imágenes a tu carpeta de fondos.")
            color: Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * s
        }

    }

    Behavior on previewAccent {
        ColorAnimation {
            duration: Flags.reduceMotion ? 0 : Motion.standard
            easing.type: Easing.OutCubic
        }

    }

}
