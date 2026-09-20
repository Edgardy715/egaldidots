import "../"
import "../Singletons"
import "../components"
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

/** Selector de fondos de Isla. Una imagen principal, navegación circular y
 * aplicación confirmada por el servicio antes de cerrar la superficie. */
PillSurface {
    id: root

    readonly property real contentW: parent.width - (mLeft + mRight) * s
    readonly property real cardW: Math.min(430 * s, contentW * 0.38)
    readonly property real cardH: Math.round(cardW * 9 / 16)
    readonly property real itemH: cardH + 28 * s
    readonly property real nearOffset: contentW * 0.28
    readonly property real farOffset: contentW * 0.46
    readonly property real sideScale: 0.6
    readonly property real sideOpacity: 0.52
    readonly property real sideTilt: 9
    property bool navigating: false
    property bool footerEntered: false
    property string pendingPath: ""
    property string feedback: ""
    property real wheelTravel: 0
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

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.previewAccent, Theme.alphaGhost)
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 58 * s
        width: 500 * s
        height: 250 * s
        radius: width / 2
        color: Qt.alpha(root.previewAccent, 0.055)
        visible: !Flags.reduceMotion
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64 * s
        z: 10
        opacity: root.footerEntered ? 1 : 0

        Item {
            x: 26 * s
            y: 55 * s
            width: parent.width - 52 * s
            height: 12 * s

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2 * s
                radius: height / 2
                color: Qt.alpha(Theme.foreground, 0.1)

                Rectangle {
                    width: wpModel.count > 0 ? parent.width * (pathView.currentIndex + 1) / wpModel.count : 0
                    height: parent.height
                    radius: height / 2
                    color: root.previewAccent

                    Behavior on width {
                        Anim {
                            type: Anim.Emphasized
                        }

                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                enabled: wpModel.count > 0 && !Wallpapers.applying
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    return root.selectIndex(Math.round(mouse.x / width * (wpModel.count - 1)));
                }
            }

        }

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

            MaterialIcon {
                anchors.centerIn: parent
                iconName: "close"
                color: Theme.foreground
                font.pixelSize: 18 * s
            }

            MouseArea {
                id: closeMouse

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

            MaterialIcon {
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

            MouseArea {
                id: refreshMouse

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
        anchors.leftMargin: mLeft * s
        anchors.rightMargin: mRight * s
        clip: true
        visible: wpModel.count > 0

        // wheel sobre la estantería → navega (mismo canal que el teclado)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                root.wheelTravel += delta;
                if (Math.abs(root.wheelTravel) >= (wheel.angleDelta.y !== 0 ? 90 : 32)) {
                    root.cycle(root.wheelTravel > 0 ? -1 : 1);
                    root.wheelTravel = 0;
                }
                wheel.accepted = true;
            }
        }

        PathView {
            id: pathView

            anchors.fill: parent
            model: wpModel
            interactive: !Wallpapers.applying
            dragMargin: 42 * s
            flickDeceleration: 1000
            pathItemCount: Math.min(wpModel.count, 5)
            cacheItemCount: 2
            snapMode: PathView.SnapOneItem
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Motion.emphasizedLarge
            onCurrentIndexChanged: {
                if (pathView.currentIndex >= 0)
                    requestVisibleThumbs();

            }

            highlight: Item {
                width: root.cardW
                height: root.itemH
            }

            path: Path {
                startX: pathView.width / 2 - root.farOffset
                startY: pathView.height / 2

                PathAttribute {
                    name: "sc"
                    value: root.sideScale
                }

                PathAttribute {
                    name: "op"
                    value: root.sideOpacity
                }

                PathAttribute {
                    name: "ry"
                    value: -root.sideTilt
                }

                PathLine {
                    x: pathView.width / 2 - root.nearOffset
                    y: pathView.height / 2
                }

                PathAttribute {
                    name: "sc"
                    value: 0.78
                }

                PathAttribute {
                    name: "op"
                    value: 0.82
                }

                PathAttribute {
                    name: "ry"
                    value: -root.sideTilt * 0.5
                }

                PathLine {
                    x: pathView.width / 2
                    y: pathView.height / 2
                }

                PathAttribute {
                    name: "sc"
                    value: 1
                }

                PathAttribute {
                    name: "op"
                    value: 1
                }

                PathAttribute {
                    name: "ry"
                    value: 0
                }

                PathLine {
                    x: pathView.width / 2 + root.nearOffset
                    y: pathView.height / 2
                }

                PathAttribute {
                    name: "sc"
                    value: 0.78
                }

                PathAttribute {
                    name: "op"
                    value: 0.82
                }

                PathAttribute {
                    name: "ry"
                    value: root.sideTilt * 0.5
                }

                PathLine {
                    x: pathView.width / 2 + root.farOffset
                    y: pathView.height / 2
                }

                PathAttribute {
                    name: "sc"
                    value: root.sideScale
                }

                PathAttribute {
                    name: "op"
                    value: root.sideOpacity
                }

                PathAttribute {
                    name: "ry"
                    value: root.sideTilt
                }

            }

            delegate: Item {
                id: del

                required property int index
                required property string path
                required property string baseName
                required property string thumb
                required property bool thumbReady
                required property string thumbSource
                required property int cacheRevision
                required property bool thumbFailed
                required property bool applied

                // valores consultados desde los PathAttributes de la ruta; fuera
                // de la ruta (invisible) → colapsados.
                readonly property bool isCurrent: PathView.isCurrentItem
                readonly property bool onPath: PathView.onPath
                readonly property real sc: PathView.onPath ? PathView.sc : 0
                readonly property real op: PathView.onPath ? PathView.op : 0
                // PathView.ry devuelve undefined cuando el item está fuera del
                // path (caching/lazy load) → ternario defensivo para evitar el
                // loop "Unable to assign undefined to double" en angle.
                readonly property real ry: PathView.onPath ? PathView.ry : 0
                // PathView interpola escala/opacidad en ambos extremos con valores
                // iguales. Ordenar por distancia circular evita empates de z que
                // hacían que una tarjeta extrema saltara encima de su vecina.
                readonly property int distanceFromCurrent: {
                    if (wpModel.count < 2) return 0
                    var distance = Math.abs(index - pathView.currentIndex)
                    return Math.min(distance, wpModel.count - distance)
                }
                property bool hovered: false

                width: root.cardW
                height: root.itemH
                // La profundidad sigue el recorrido, incluso al seleccionar un
                // extremo: cada tarjeta queda detrás de las más próximas al centro.
                z: 10 - del.distanceFromCurrent
                // profundidad: inclinación diagonal del cover-flow + los laterales
                // quedan un pelín hundidos respecto al centro.
                transform: [
                    Rotation {
                        axis.x: 0
                        axis.y: 1
                        axis.z: 0
                        // PathView ya interpola estos valores en cada fotograma.
                        angle: del.ry
                    },
                    Translate {
                        y: (1 - del.sc) * 7 * root.s
                    }
                ]

                Item {
                    id: inner

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: root.cardW
                    height: root.itemH
                    scale: del.sc
                    opacity: del.op
                    transformOrigin: Item.Center

                    Item {
                        id: cardSlot

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.cardW
                        height: root.cardH

                        Item {
                            anchors.centerIn: parent
                            width: parent.width + 8 * root.s
                            height: parent.height + 8 * root.s

                            BreatheBorder {
                                radius: Motion.rTile * root.s + 4 * root.s
                                s: root.s
                                width_: 1
                                alphaMin: 0
                                alphaMax: 0.24
                                period: 2900
                                glowColor: root.previewAccent
                                running: isCurrent && del.onPath && root.open && !Flags.reduceMotion
                            }

                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: Motion.rTile * root.s
                            color: Theme.cardBot
                            border.width: Theme.borderHairline
                            border.color: Theme.border
                            layer.enabled: del.isCurrent && del.onPath

                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                                shadowBlur: 0.7
                                shadowVerticalOffset: 8 * root.s
                            }

                        }

                        ClippingRectangle {
                            id: board

                            anchors.fill: parent
                            radius: Motion.rTile * root.s
                            scale: del.hovered && del.isCurrent ? 1.015 : 1
                            border.width: Theme.borderHairline
                            border.color: Theme.border
                            color: Theme.cardBot
                            contentInsideBorder: false
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Theme.cardTop }
                                    GradientStop { position: 1; color: Theme.cardBot }
                                }
                            }

                            Image {
                                id: thumbImage

                                anchors.fill: parent
                                source: del.thumbReady ? del.thumbSource : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                sourceSize: Qt.size(board.width * 2, board.height * 2)
                                antialiasing: true
                                opacity: status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Motion.fast
                                        easing.type: Easing.OutQuad
                                    }

                                }

                            }

                            Image {
                                id: fullImage

                                anchors.fill: parent
                                source: del.isCurrent ? ("file://" + encodeURI(del.path)) : ""
                                sourceSize: Qt.size(board.width * 2, board.height * 2)
                                asynchronous: true
                                smooth: true
                                fillMode: Image.PreserveAspectCrop
                                opacity: del.isCurrent && status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Motion.standardLarge
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.cardBot
                                opacity: thumbImage.status === Image.Ready || fullImage.status === Image.Ready ? 0 : 1

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.FastEffects
                                    }

                                }

                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !del.thumbReady && !del.thumbFailed && del.onPath
                                color: "transparent"

                                Rectangle {
                                    width: board.width * 0.5
                                    height: parent.height
                                    color: Qt.alpha(root.previewAccent, Theme.alphaFaint)

                                    SequentialAnimation on x {
                                        running: !del.thumbReady && !del.thumbFailed && del.onPath && root.open && !Flags.reduceMotion
                                        loops: Animation.Infinite

                                        NumberAnimation {
                                            from: -board.width * 0.5
                                            to: board.width
                                            duration: 1100
                                            easing.type: Easing.InOutCubic
                                        }

                                        NumberAnimation {
                                            from: board.width
                                            to: -board.width * 0.5
                                            duration: 0
                                        }

                                    }

                                }

                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: (del.thumbFailed || thumbImage.status === Image.Error) && fullImage.status !== Image.Ready
                                iconName: "broken_image"
                                color: Theme.dim
                                font.pixelSize: 28 * root.s
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 34 * root.s
                                visible: del.isCurrent

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }

                                    GradientStop {
                                        position: 1
                                        color: Qt.rgba(0, 0, 0, 0.46)
                                    }

                                }

                            }

                            // wash de hover (la tarjeta "se enciende" bajo el cursor)
                            Rectangle {
                                anchors.fill: parent
                                radius: board.radius
                                color: Qt.alpha(root.previewAccent, del.hovered && del.onPath ? 0.1 : 0)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Motion.fast
                                    }

                                }

                            }

                            // borde del piloto / hover
                            Rectangle {
                                anchors.fill: parent
                                radius: board.radius
                                color: "transparent"
                                border.width: (isCurrent || (onPath && hovered)) ? 2 : 0
                                border.color: isCurrent ? root.previewAccent : Qt.alpha(root.previewAccent, Theme.alphaCritical)

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Motion.fast
                                    }

                                }

                                Behavior on border.width {
                                    Anim {
                                        type: Anim.FastEffects
                                    }

                                }

                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 10 * root.s
                                width: 24 * root.s
                                height: 24 * root.s
                                radius: width / 2
                                color: root.previewAccent
                                opacity: del.applied ? 1 : 0
                                visible: opacity > 0
                                scale: del.applied ? 1 : 0.6

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: Icons.iCheck
                                    color: root.onPreviewAccent
                                    font.pixelSize: Theme.fontSizeBody * root.s
                                }

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.FastEffects
                                    }

                                }

                                Behavior on scale {
                                    Anim {
                                        type: Anim.Emphasized
                                    }

                                }

                            }

                            MouseArea {
                                id: tileMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    del.hovered = containsMouse;
                                }
                                onClicked: {
                                    if (!isCurrent)
                                        root.selectIndex(index);

                                }
                                onDoubleClicked: root.applyPath(del.path)
                            }

                            Behavior on scale {
                                Anim {
                                    type: Anim.FastSpatial
                                }

                            }

                        }

                    }

                }

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
                    scale: navMouse.pressed ? 0.92 : 1

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: modelData
                        color: Theme.foreground
                        font.pixelSize: 22 * root.s
                    }

                    MouseArea {
                        id: navMouse

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

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }

                    }

                }

            }

            Rectangle {
                width: 164 * root.s
                height: 40 * root.s
                radius: Theme.radiusLg * root.s
                color: applyMouse.pressed ? Qt.darker(root.previewAccent, 1.1) : applyMouse.containsMouse ? Qt.lighter(root.previewAccent, 1.1) : root.previewAccent
                opacity: Wallpapers.applying ? 0.65 : 1
                scale: applyMouse.pressed ? 0.97 : 1

                Row {
                    anchors.centerIn: parent
                    spacing: 7 * root.s

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
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
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.feedback === "done" ? "Listo" : Wallpapers.applying ? "Aplicando…" : "Aplicar fondo"
                        color: root.onPreviewAccent
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                    }

                }

                MouseArea {
                    id: applyMouse

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

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
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
                running: Wallpapers.scanning
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
