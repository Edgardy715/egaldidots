import "../"
import "../Singletons"
import "../components"
import QtQuick
import Quickshell.Widgets

/** Selector de fondos de Isla. Una imagen principal, navegación circular y
 * aplicación confirmada por el servicio antes de cerrar la superficie. */
PillSurface {
    id: root

    property bool navigating: false
    property bool footerEntered: false
    property string pendingPath: ""
    property string feedback: ""
    property real wheelTravel: 0
    property url previousPreview: ""
    property url readyPreview: ""
    readonly property var sel: wpModel.count > 0 ? wpModel.get(Math.max(0, Math.min(pathView.currentIndex, wpModel.count - 1))) : null
    readonly property string selName: sel ? displayName(sel.baseName || "") : ""
    readonly property bool selApplied: sel ? (sel.applied === true) : false
    property color previewAccent: Wallpapers.accentFor(sel ? sel.path : "", Theme.accent)
    readonly property color onPreviewAccent: (0.2126 * previewAccent.r + 0.7152 * previewAccent.g + 0.0722 * previewAccent.b) > 0.52 ? "#101116" : "#ffffff"

    function displayName(name) {
        if (name.startsWith("wallhaven-"))
            return "Wallhaven  ·  " + name.slice(10).toUpperCase();

        return name.replace(/[_-]+/g, " ");
    }

    function selectIndex(index) {
        if (wpModel.count === 0 || Wallpapers.applying)
            return ;

        navigating = true;
        navigateTimer.restart();
        pathView.currentIndex = ((index % wpModel.count) + wpModel.count) % wpModel.count;
    }

    function cycle(dir) {
        selectIndex(pathView.currentIndex + dir);
    }

    function goIndex(num) {
        if (wpModel.count === 0)
            return ;

        var idx = num === 0 ? 9 : num - 1;
        if (idx < 0 || idx >= wpModel.count)
            return ;

        selectIndex(idx);
    }

    function commitSelection() {
        if (wpModel.count === 0 || Wallpapers.applying || feedback === "done")
            return ;

        var item = wpModel.get(pathView.currentIndex);
        if (!item)
            return ;

        pendingPath = item.path;
        if (Wallpapers.setWallpaper(item.path))
            feedback = "applying";
        else
            feedback = "error";
    }

    function applyPath(path) {
        if (!path)
            return ;

        for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === path) {
            selectIndex(i);
            break;
        }
        commitSelection();
    }

    function syncCurrentIndex() {
        if (wpModel.count === 0 || navigating)
            return ;

        if (Wallpapers.current !== "") {
            for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === Wallpapers.current) {
                pathView.currentIndex = i;
                return ;
            }
        }
        pathView.currentIndex = 0;
    }

    function requestVisibleThumbs() {
        if (wpModel.count === 0)
            return ;

        for (var offset = -3; offset <= 3; offset++) {
            var i = ((pathView.currentIndex + offset) % wpModel.count + wpModel.count) % wpModel.count;
            var it = wpModel.get(i);
            if (it && !it.thumbReady && !it.thumbFailed)
                Wallpapers.requestThumbnail(it.path, it.thumb);

        }
    }

    mTop: Theme.marginSm
    mLeft: Theme.marginXl
    mRight: Theme.marginXl
    mBottom: Theme.marginXs
    Component.onCompleted: {
        // antes había un syncTimer que poleaba cada 100ms hasta que
        // Wallpapers.count > 0, lo que gastaba CPU en reposo y se detenía solo
        // tras la primera carga. Ahora conectamos reactivamente: si la lista ya
        // está llena al abrir la surface, sincronizamos de inmediato; si está
        // vacía y nadie escanea, forzamos el primer scan.
        if (Wallpapers.count > 0) {
            wpModel.sync();
            syncCurrentIndex();
            requestVisibleThumbs();
        } else if (!Wallpapers.scanning) {
            Wallpapers.forceRefresh();
        }
    }
    onOpenChanged: {
        if (open) {
            navigating = false;
            feedback = "";
            footerEntered = false;
            syncCurrentIndex();
        }
    }

    Timer {
        id: navigateTimer

        interval: 2000
        onTriggered: navigating = false
    }

    Timer {
        interval: Motion.stagger(6)
        running: root.open && !root.footerEntered
        repeat: false
        onTriggered: root.footerEntered = true
    }

    Timer {
        id: closeTimer

        interval: Math.max(500, Math.round(760 * Motion.mult))
        onTriggered: root.requestClose()
    }

    ListModel {
        id: wpModel

        function sync() {
            var src = Wallpapers.list;
            var same = src.length === wpModel.count;
            if (same) {
                for (var i = 0; i < src.length; i++) if (wpModel.get(i).path !== src[i].path) {
                    same = false;
                    break;
                }
            }
            if (same) {
                for (var i = 0; i < src.length; i++) {
                    var w = src[i];
                    wpModel.set(i, {
                        "path": w.path,
                        "baseName": w.baseName,
                        "thumb": w.thumb,
                        "thumbReady": w.thumbReady === true,
                        "thumbSource": w.thumbReady ? ("file://" + encodeURI(w.thumb)) : "",
                        "cacheRevision": w.cacheRevision || 0,
                        "shimmer": !w.thumbReady,
                        "thumbFailed": false,
                        "applied": w.path === Wallpapers.current
                    });
                }
            } else {
                wpModel.clear();
                for (var i = 0; i < src.length; i++) {
                    var w = src[i];
                    wpModel.append({
                        "path": w.path,
                        "baseName": w.baseName,
                        "thumb": w.thumb,
                        "thumbReady": w.thumbReady === true,
                        "thumbSource": w.thumbReady ? ("file://" + encodeURI(w.thumb)) : "",
                        "cacheRevision": w.cacheRevision || 0,
                        "shimmer": !w.thumbReady,
                        "thumbFailed": false,
                        "applied": w.path === Wallpapers.current
                    });
                }
            }
        }

    }

    Connections {
        function onListChanged() {
            wpModel.sync();
            if (!navigating) {
                syncCurrentIndex();
                requestVisibleThumbs();
            }
        }

        function onCurrentChanged() {
            if (!navigating)
                syncCurrentIndex();

            wpModel.sync();
        }

        function onApplyFinished(path, success) {
            if (path !== root.pendingPath)
                return ;

            root.feedback = success ? "done" : "error";
            if (success) {
                applyBurst.burst();
                closeTimer.restart();
            }
        }

        function onThumbUpdated(path, thumbSource, cacheRevision) {
            for (var i = 0; i < wpModel.count; i++) {
                if (wpModel.get(i).path === path) {
                    wpModel.setProperty(i, "thumbSource", thumbSource);
                    wpModel.setProperty(i, "cacheRevision", cacheRevision);
                    wpModel.setProperty(i, "thumbReady", true);
                    wpModel.setProperty(i, "shimmer", false);
                    wpModel.setProperty(i, "thumbFailed", false);
                    break;
                }
            }
        }

        function onThumbFailed(path) {
            for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === path) {
                wpModel.setProperty(i, "thumbFailed", true);
                break;
            }
        }

        target: Wallpapers
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64 * s
        z: 10
        opacity: root.footerEntered ? 1 : 0

        Rectangle {
            x: 23 * s
            y: 16 * s
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
            y: 13 * s
            spacing: 1 * s

            Text {
                text: "Fondos de pantalla"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 18 * s
                font.weight: Font.DemiBold
            }

            Text {
                text: qsTr("%1 fondos disponibles").arg(wpModel.count)
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Theme.font
                font.pixelSize: 11 * s
            }

        }

        Rectangle {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 22 * s
            y: 18 * s
            width: 30 * s
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
            width: 30 * s
            height: width
            radius: Theme.radiusSm * s
            color: refreshMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.13) : Qt.alpha(Theme.foreground, 0.06)

            MotionArea {
                id: refreshMouse
                accessibleName: qsTr("Actualizar fondos")

                anchors.fill: parent
                enabled: !Wallpapers.applying
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.forceRefresh()
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
                    running: Wallpapers.scanning && root.open && !Flags.reduceMotion
                }

            }

        }

        Row {
            anchors.right: refreshButton.left
            anchors.rightMargin: 116 * root.s
            anchors.verticalCenter: refreshButton.verticalCenter
            spacing: 10 * root.s
            visible: Players.has

            IslandMediaSummary {
                s: root.s
                coverDiameter: 32 * root.s
                textWidth: 200 * root.s
                spacing: 10 * root.s
                metadataSpacing: 2 * root.s
                titlePixelSize: 12.5 * root.s
                artistPixelSize: 11 * root.s
                artUrl: Players.artUrl
                hasProgress: Players.active && Players.active.length > 0
                progress: hasProgress ? Math.max(0, Math.min(1,
                    Players.active.position / Players.active.length)) : 0
                title: Players.title
                artist: Players.artist
            }
        }

        Text {
            anchors.right: refreshButton.left
            anchors.rightMargin: 16 * s
            anchors.verticalCenter: refreshButton.verticalCenter
            text: wpModel.count > 0 ? (pathView.currentIndex + 1) + " / " + wpModel.count : "—"
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
        visible: wpModel.count > 0

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
                    opacity: root.previousPreview.toString().length > 0 ? 0 : 1 - heroImage.opacity
                    sourceSize: Qt.size(960, 540)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Image {
                    anchors.fill: parent
                    objectName: "previousPreview"
                    source: root.previousPreview
                    opacity: 1 - heroImage.opacity
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Image {
                    id: heroImage
                    objectName: "heroImage"
                    anchors.fill: parent
                    source: root.sel ? "file://" + encodeURI(root.sel.path) : ""
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    opacity: 0
                    function revealReady() {
                        if (status !== Image.Ready || heroReveal.running || opacity === 1) return
                        root.readyPreview = source
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
                    }
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
                    color: Theme.dim
                    font.pixelSize: 30 * root.s
                }
            }
        }

        ListView {
            id: pathView
            objectName: "wallpaperThumbnails"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 66 * root.s
            orientation: ListView.Horizontal
            spacing: 10 * root.s
            model: wpModel
            clip: true
            interactive: !Wallpapers.applying
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 48 * root.s
            preferredHighlightEnd: width / 2 + 48 * root.s
            highlightMoveDuration: Flags.reduceMotion ? 0 : Motion.morph
            onCurrentIndexChanged: root.requestVisibleThumbs()

            delegate: Item {
                id: thumbnail
                required property int index
                required property string thumbSource
                required property string path
                required property string thumb
                required property bool thumbReady
                required property bool applied
                required property bool thumbFailed
                readonly property bool selected: ListView.isCurrentItem
                Component.onCompleted: {
                    if (!thumbReady && !thumbFailed) Wallpapers.requestThumbnail(path, thumb)
                }
                width: 96 * root.s
                height: pathView.height
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 54 * root.s
                    radius: 8 * root.s
                    color: Theme.cardBot
                    border.width: thumbnail.selected ? 2 * root.s : Theme.borderHairline
                    border.color: thumbnail.selected ? root.previewAccent : Theme.border
                    opacity: thumbnail.selected || thumbMouse.containsMouse ? 1 : 0.72
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 3 * root.s
                        source: thumbnail.thumbSource
                        sourceSize: Qt.size(192, 108)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MaterialIcon {
                        interaction: thumbMouse.motion
                        hovered: thumbMouse.containsMouse
                        scale: thumbMouse.motion.visualScale
                        anchors.centerIn: parent
                        visible: thumbnail.thumbFailed
                        iconName: "broken_image"
                        color: Theme.dim
                        font.pixelSize: 18 * root.s
                    }
                    MotionArea {
                        id: thumbMouse
                        accessibleName: qsTr("Seleccionar fondo")
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Wallpapers.applying
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectIndex(thumbnail.index)
                        onDoubleClicked: root.applyPath(thumbnail.path)
                    }
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
        height: 88 * s
        visible: wpModel.count > 0
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
            width: Math.max(1, footer.width - 340 * s)
            spacing: 5 * s

            Text {
                width: parent.width
                text: root.selName
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 17 * s
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }

            Text {
                width: parent.width
                text: root.feedback === "applying" ? "Cambiando fondo y colores…" : root.feedback === "done" ? "Fondo aplicado" : root.feedback === "error" ? Wallpapers.applyError : root.selApplied ? "Fondo actual  ·  ← → para explorar" : "← → navegar  ·  Intro o doble clic para aplicar"
                color: root.feedback === "error" ? "#ff9ba6" : root.feedback === "done" ? root.previewAccent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Theme.font
                font.pixelSize: 11 * s
                elide: Text.ElideRight
            }

        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 24 * s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * s

            Repeater {
                model: ["chevron_left", "chevron_right"]

                delegate: Rectangle {
                    required property int index
                    required property string modelData

                    width: 40 * root.s
                    height: width
                    radius: Theme.radiusLg * root.s
                    color: navMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.14) : Qt.alpha(Theme.foreground, 0.07)
                    border.width: Theme.borderHairline
                    border.color: Theme.border

                    MotionArea {
                        id: navMouse
                        accessibleName: index === 0 ? qsTr("Anterior") : qsTr("Siguiente")

                        anchors.fill: parent
                        enabled: !Wallpapers.applying
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycle(index === 0 ? -1 : 1)
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.fast
                        }

                    }

                    MaterialIcon {
                        compressWithControl: true
                        interaction: navMouse.motion
                        hovered: navMouse.containsMouse
                        anchors.centerIn: parent
                        iconName: modelData
                        color: Theme.foreground
                        font.pixelSize: 22 * root.s
                    }

}

            }

            Rectangle {
                width: 164 * root.s
                height: 40 * root.s
                radius: Theme.radiusLg * root.s
                color: applyMouse.pressed ? Qt.darker(root.previewAccent, 1.1) : applyMouse.containsMouse ? Qt.lighter(root.previewAccent, 1.1) : root.previewAccent
                opacity: Wallpapers.applying ? 0.65 : 1

                MotionArea {
                    id: applyMouse
                    accessibleName: qsTr("Aplicar fondo")

                    anchors.fill: parent
                    enabled: !Wallpapers.applying && root.feedback !== "done"
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
                        iconName: root.feedback === "done" ? Icons.iCheck : Wallpapers.applying ? "progress_activity" : "wallpaper"
                        color: root.onPreviewAccent
                        font.pixelSize: 18 * root.s

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 850
                            loops: Animation.Infinite
                            running: Wallpapers.applying && root.open && !Flags.reduceMotion
                        }

                    }

                    Text {
                        scale: applyMouse.motion.visualScale
                        transform: Translate { y: -Motion.labelTravel * applyMouse.motion.presence }
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.feedback === "done" ? "Listo" : Wallpapers.applying ? "Aplicando…" : "Aplicar fondo"
                        color: root.onPreviewAccent
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
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
        visible: wpModel.count === 0

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
                color: Theme.dim
                font.pixelSize: Theme.fontSizeHero * s
            }

            SequentialAnimation on opacity {
                running: Wallpapers.scanning && root.open && !Flags.reduceMotion
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
            text: Wallpapers.scanning ? "Escaneando fondos…" : "Sin fondos"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.hBody * s
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Wallpapers.scanning
            text: "Añade imágenes a ~/Wallpapers y se indexarán solas"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.hCaption * s
        }

    }

    Item {
        id: applyBurst

        function burst() {
            applyBurst.visible = true;
            burstAnim.restart();
        }

        anchors.centerIn: parent
        width: 82 * s
        height: 82 * s
        visible: false
        opacity: 0
        z: 999

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(Theme.background, 0.92)
            border.width: Theme.borderEmphasis
            border.color: root.previewAccent
        }

        MaterialIcon {
            anchors.centerIn: parent
            iconName: Icons.iCheck
            color: root.previewAccent
            font.pixelSize: 42 * s
        }

        SequentialAnimation {
            id: burstAnim

            ParallelAnimation {
                PropertyAnimation {
                    target: applyBurst
                    property: "scale"
                    from: 0.65
                    to: 1.05
                    duration: Motion.emphasized
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.emphasizedDecelCurve
                }

                PropertyAnimation {
                    target: applyBurst
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.standardSmall
                    easing.type: Easing.OutCubic
                }

            }

            PauseAnimation {
                duration: Math.round(120 * Motion.mult)
            }

            PropertyAnimation {
                target: applyBurst
                property: "opacity"
                from: 1
                to: 0
                duration: Motion.standard
                easing.type: Easing.InCubic
            }

            ScriptAction {
                script: {
                    applyBurst.visible = false;
                    applyBurst.opacity = 0;
                }
            }

        }

    }

    Behavior on previewAccent {
        ColorAnimation {
            duration: Motion.morph
            easing.type: Easing.OutCubic
        }

    }

}
