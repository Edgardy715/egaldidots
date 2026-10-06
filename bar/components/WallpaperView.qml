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
    readonly property var sel: wallpaperModel && wallpaperModel.count > 0
        ? wallpaperModel.get(Math.max(0, Math.min(pathView.currentIndex, wallpaperModel.count - 1))) : null
    readonly property string selName: sel ? displayName(sel.baseName || "") : ""
    readonly property bool selApplied: sel ? sel.applied === true : false
    readonly property color onPreviewAccent: (0.2126 * previewAccent.r + 0.7152 * previewAccent.g + 0.0722 * previewAccent.b) > 0.52 ? "#101116" : "#ffffff"
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
        if (!wallpaperModel || wallpaperModel.count === 0 || applying) return
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
    function commitSelection() { commitRequested(pathView.currentIndex) }
    function applyPath(path) { applyPathRequested(path) }
    function applied() { applyBurst.burst(); closeTimer.restart() }
    onOpenChanged: if (open) { navigating = false; footerEntered = false }
    Timer { id: navigateTimer; interval: 2000; onTriggered: root.navigating = false }
    Timer {
        interval: Motion.stagger(6)
        running: root.open && !root.footerEntered
        onTriggered: root.footerEntered = true
    }
    Timer {
        id: closeTimer
        interval: Math.max(500, Math.round(760 * Motion.mult))
        onTriggered: root.requestClose()
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
                text: qsTr("%1 fondos disponibles").arg(root.wallpaperModel.count)
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
                enabled: !root.applying
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
                    running: root.scanning && root.open && !Flags.reduceMotion
                }

            }

        }

        Row {
            anchors.right: refreshButton.left
            anchors.rightMargin: 116 * root.s
            anchors.verticalCenter: refreshButton.verticalCenter
            spacing: 10 * root.s
            visible: root.mediaHas

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
            text: root.wallpaperModel.count > 0 ? (pathView.currentIndex + 1) + " / " + root.wallpaperModel.count : "—"
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
        visible: root.wallpaperModel.count > 0

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
                        onFinished: if (heroImage.status === Image.Ready) root.readyPreview = heroImage.source
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
            model: root.wallpaperModel
            clip: true
            interactive: !root.applying
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 48 * root.s
            preferredHighlightEnd: width / 2 + 48 * root.s
            highlightMoveDuration: Flags.reduceMotion ? 0 : Motion.morph
            onCurrentIndexChanged: root.selectionChanged(currentIndex)

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
                    if (!thumbReady && !thumbFailed) root.thumbnailRequested(path, thumb)
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
                        enabled: !root.applying
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
        visible: root.wallpaperModel.count > 0
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
                text: root.feedback === "applying" ? "Cambiando fondo y colores…" : root.feedback === "done" ? "Fondo aplicado" : root.feedback === "error" ? root.applyError : root.selApplied ? "Fondo actual  ·  ← → para explorar" : "← → navegar  ·  Intro o doble clic para aplicar"
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
                        enabled: !root.applying
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
                opacity: root.applying ? 0.65 : 1

                MotionArea {
                    id: applyMouse
                    accessibleName: qsTr("Aplicar fondo")

                    anchors.fill: parent
                    enabled: !root.applying && root.feedback !== "done"
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
                            running: root.applying && root.open && !Flags.reduceMotion
                        }

                    }

                    Text {
                        scale: applyMouse.motion.visualScale
                        transform: Translate { y: -Motion.labelTravel * applyMouse.motion.presence }
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.feedback === "done" ? "Listo" : root.applying ? "Aplicando…" : "Aplicar fondo"
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
        visible: root.wallpaperModel.count === 0

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
                running: root.scanning && root.open && !Flags.reduceMotion
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
