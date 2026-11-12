pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Wayland
import Quickshell.Widgets
import "../"
import "../Singletons"
import "../components"

/** Compact workspace strip with live previews and keyboard navigation. */
PillSurface {
    id: root
    mTop: 24
    mLeft: 26
    mRight: 26
    mBottom: 20

    property var mon: null
    readonly property int monId: mon ? mon.id : -1
    readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : 1
    property bool loading: false
    property var windowsByWorkspace: ({})
    property var toplevelByAddress: ({})
    property string wallpaperSource: ""
    property bool hasMedia: false
    property string mediaArtUrl: ""
    property bool mediaHasProgress: false
    property real mediaProgress: 0
    property string mediaTitle: ""
    property string mediaArtist: ""
    signal workspaceRequested(int id)
    function _onDataReady() {} // Public host hook; selection is independent of windows.

    readonly property real usableW: mon ? Math.max(2, mon.width / mon.scale - (mon.reserved[0] || 0) - (mon.reserved[2] || 0)) : root.width
    readonly property real usableH: mon ? Math.max(2, mon.height / mon.scale - (mon.reserved[1] || 0) - (mon.reserved[3] || 0)) : root.height
    readonly property real baseX: mon ? mon.x + (mon.reserved[0] || 0) : 0
    readonly property real baseY: mon ? mon.y + (mon.reserved[1] || 0) : 0
    readonly property real screenAspect: root.usableW / root.usableH

    // ---- layout ----
    readonly property int cols: 4
    readonly property int rows: 1
    readonly property int groupSize: cols * rows
    // mutable: la wheel del grupo lo desplaza (ventana deslizante sobre ws)
    property int groupBase: Math.floor((activeId - 1) / groupSize) * groupSize + 1
    readonly property var visibleIds: {
        var out = []
        for (var i = 0; i < root.groupSize; i++) out.push(root.groupBase + i)
        return out
    }

    readonly property real gap: 18 * s
    readonly property real tileW: Math.max(1, (root.width - 3 * gap) / 4)
    readonly property real tileH: Math.max(1, Math.min(tileW / screenAspect, root.height - 148 * s))

    // ---- navegación por teclado ----
    // El overview selecciona WORKSPACES (los tabs de arriba + tiles), no ventanas:
    //   Tab recorre controles; →/↓ = siguiente ws, ←/↑ = anterior, Enter/Space = ir a ese ws.
    // Las previews de ventanas dan contexto, pero la acción es cambiar de workspace.
    // (El viejo comportamiento enfocaba una VENTANA y fallaba cuando flatWins estaba
    // vacío por la carga async de WinMap — por eso "Enter no llevaba a la pestaña".)
    readonly property int selWs: {
        var i = root.visibleIds.indexOf(root._selIndexWs)
        return i >= 0 ? root._selIndexWs : root.activeId
    }
    property int _selIndexWs: -1
    // "último input manda": el hover del mouse NO debe pisar la selección que el
    // usuario hace con el teclado (bug: mouse sobre el tile activo → Enter iba al ws 2).
    // keyNav=true tras usar teclado; un movimiento REAL del mouse lo desactiva.
    property bool selectionTouched: false
    property bool _keyNav: false
    function _keyMove() { root._keyNav = true; root.selectionTouched = true }
    function _mouseMove() { root._keyNav = false; root.selectionTouched = true }
    function _hoverSelect(wsId) {
        if (root._keyNav) return
        root._selIndexWs = wsId
    }
    readonly property int _selWsIndex: {
        var i = root.visibleIds.indexOf(root.selWs)
        return i >= 0 ? i : 0
    }
    function cycle(delta) {
        root._keyMove()
        var n = root.visibleIds.length
        if (n === 0) return
        // arranca desde el ws activo (o el previamente seleccionado)
        var start = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var i = root.visibleIds.indexOf(start)
        if (i < 0) i = delta > 0 ? -1 : 0
        var ni = ((i + delta) % n + n) % n
        root._selIndexWs = root.visibleIds[ni]
    }
    /** Movimiento por FILAS (j/k): cambia de fila manteniendo la columna. */
    function cycleRow(deltaRows) {
        if (root.rows === 1) { root.shiftGroup(deltaRows); return }
        root._keyMove()
        var n = root.visibleIds.length
        if (n === 0) return
        var start = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var i = root.visibleIds.indexOf(start)
        if (i < 0) i = 0
        var col = i % root.cols
        var row = Math.floor(i / root.cols)
        var nr = ((row + deltaRows) % root.rows + root.rows) % root.rows
        var ni = nr * root.cols + col
        root._selIndexWs = root.visibleIds[ni]
    }
    /** Salto directo: 1-9 → workspace de la posición N del grupo (0 → posición 10). */
    function goIndex(num) {
        root._keyMove()
        if (num === 0) num = 10
        var idx = num - 1
        if (idx >= 0 && idx < root.visibleIds.length)
            root._selIndexWs = root.visibleIds[idx]
    }
    /** Wheel: desplaza el GRUPO visible (ventana deslizante sobre todos los ws). */
    function shiftGroup(delta) {
        root._keyMove()
        var span = Math.max(1, root.visibleIds.length)
        var cur = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var groupIdx = Math.floor((cur - 1) / span)
        var next = Math.max(0, groupIdx + delta)
        var base = next * span + 1
        if (base !== root.groupBase) root._slideGroup(base > root.groupBase ? 1 : -1)
        root.groupBase = base
        root._selIndexWs = base
        root.selectionSnap = false
    }
    // A group change slides the strip in its direction; the selection ring
    // jumps with it instead of travelling across the old tiles.
    property bool selectionSnap: false
    property real groupShift: 0
    function _slideGroup(dir) {
        root.selectionSnap = true
        if (Flags.reduceMotion || !root.open) return
        groupSlide.from = dir * 28 * root.s
        groupSlide.restart()
        groupFade.restart()
    }
    NumberAnimation { id: groupSlide; target: root; property: "groupShift"; to: 0; duration: Motion.standard; easing.type: Motion.easeStandard }
    property real groupReveal: 1
    NumberAnimation { id: groupFade; target: root; property: "groupReveal"; from: 0.35; to: 1; duration: Motion.standard; easing.type: Motion.easeStandard }
    function commitSelection() {
        // Leer el índice directamente al confirmar. `selWs` es una propiedad
        // derivada y durante el mismo evento de teclado puede conservar su valor
        // anterior un frame; eso hacía que Enter reabriera el workspace activo.
        var i = root.visibleIds.indexOf(root._selIndexWs)
        var target = i >= 0 ? root._selIndexWs : root.activeId
        if (target > 0) root.goWorkspace(target)
        else root.requestClose()
    }
    onActiveIdChanged: if (root.open && !root.selectionTouched) {
        const base = Math.floor((root.activeId - 1) / root.groupSize) * root.groupSize + 1
        root.selectionSnap = base !== root.groupBase
        root.groupBase = base
        root._selIndexWs = root.activeId
        root.selectionSnap = false
    }

    onOpenChanged: {
        if (root.open) {
            // Opening places the ring; it only travels for later selections.
            root.selectionSnap = true
            root.selectionTouched = false
            root.groupBase = Math.floor((root.activeId - 1) / root.groupSize) * root.groupSize + 1
            root._selIndexWs = root.activeId
            root._keyNav = true
            root.selectionSnap = false
        } else {
            root._selIndexWs = -1
            root._keyNav = false
        }
    }

    function goWorkspace(id) {
        if (id < 1) return
        workspaceRequested(id)
        requestClose()
    }

    Column {
        anchors.fill: parent
        spacing: 18 * root.s
        Item {
            width: parent.width
            height: 46 * root.s
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                Text {
                    text: I18n.tr("Tus escritorios")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 20 * root.s
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                }
                AnimatedLabel {
                    value: I18n.tr("Espacios %1–%2").arg(root.groupBase).arg(root.groupBase + root.groupSize - 1)
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    color: Theme.iconSecondary
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s
                visible: root.hasMedia
                IslandMediaSummary {
                    s: root.s
                    coverDiameter: 34 * root.s
                    textWidth: 220 * root.s
                    spacing: 10 * root.s
                    metadataSpacing: 3 * root.s
                    titlePixelSize: 13 * root.s
                    artistPixelSize: 11 * root.s
                    artUrl: root.mediaArtUrl
                    hasProgress: root.mediaHasProgress
                    progress: root.mediaProgress
                    title: root.mediaTitle
                    artist: root.mediaArtist
                }
            }
        }
        Item {
            width: parent.width
            height: root.tileH + 36 * root.s
        Row {
            id: strip
            spacing: root.gap
            opacity: root.groupReveal
            transform: Translate { x: root.groupShift }
            // Fixed slots: changing group retargets the previews instead of
            // rebuilding every tile and its screencopy.
            Repeater {
                model: root.groupSize
                delegate: Item {
                    id: tile
                    required property int index
                    readonly property int wsId: root.groupBase + index
                    readonly property bool selected: root.selWs === wsId
                    readonly property bool activeWorkspace: root.activeId === wsId
                    readonly property var windows: root.windowsByWorkspace[wsId] || []
                    width: root.tileW
                    height: root.tileH + 36 * root.s
                    RectangularGlow {
                        anchors.fill: desktop
                        anchors.margins: -2 * root.s
                        cornerRadius: desktop.radius + 2 * root.s
                        glowRadius: 8 * root.s
                        spread: 0.08
                        color: Theme.accent
                        opacity: tile.selected ? 0.24 : 0
                        visible: root.open && root.visible && opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                    }
                    ClippingRectangle {
                        id: desktop
                        objectName: "workspacePreview"
                        width: parent.width
                        height: root.tileH
                        radius: 12 * root.s
                        color: Theme.cardBot
                        border.width: Theme.borderHairline
                        border.color: Qt.alpha(Theme.foreground, 0.16)
                        contentInsideBorder: true
                        Image {
                            anchors.fill: parent
                            source: root.wallpaperSource
                            sourceSize: Qt.size(480, 270)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: tile.windows.length ? 0.55 : 0.8
                            Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                        }
                        Repeater {
                            model: tile.windows
                            delegate: Rectangle {
                                id: windowPreview
                                required property var modelData
                                readonly property var capturedToplevel: root.toplevelByAddress[modelData.address] || null
                                x: ((modelData.at[0] || 0) - root.baseX) / root.usableW * desktop.width
                                y: ((modelData.at[1] || 0) - root.baseY) / root.usableH * desktop.height
                                width: Math.max(8 * root.s, modelData.size[0] / root.usableW * desktop.width)
                                height: Math.max(8 * root.s, modelData.size[1] / root.usableH * desktop.height)
                                radius: 4 * root.s
                                color: Theme.cardTop
                                border.color: Qt.alpha(Theme.foreground, 0.2)
                                clip: true
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: root.open ? windowPreview.capturedToplevel : null
                                    live: root.open && root.visible && windowPreview.capturedToplevel !== null
                                    visible: windowPreview.capturedToplevel !== null
                                }
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 6 * root.s
                                    text: windowPreview.modelData.class || ""
                                    font.family: Theme.font
                                    font.pixelSize: 11 * root.s
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: windowPreview.capturedToplevel === null
                                }
                            }
                        }
                        MotionArea {
                            anchors.fill: parent
                            accessibleName: I18n.tr("Ir al escritorio %1").arg(tile.wsId)
                            focusOnTab: false
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: { root._mouseMove(); root._hoverSelect(tile.wsId) }
                            onClicked: root.goWorkspace(tile.wsId)
                        }
                    }
                    AnimatedLabel {
                        anchors.right: parent.right
                        anchors.rightMargin: 3 * root.s
                        anchors.top: desktop.bottom
                        anchors.topMargin: 11 * root.s
                        value: tile.windows.length ? String(tile.windows.length) : ""
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        color: Theme.iconSecondary
                    }
                    Row {
                        anchors.top: desktop.bottom
                        anchors.topMargin: 10 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: 3 * root.s
                        spacing: 6 * root.s
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4 * root.s; height: width; radius: width / 2
                            color: Theme.accent
                            opacity: tile.activeWorkspace ? 1 : 0
                            scale: 0.4 + 0.6 * opacity
                            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        }
                        Text {
                            text: I18n.tr("Escritorio %1").arg(tile.wsId)
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            color: tile.selected ? Theme.foreground : Theme.iconSecondary
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        }
                    }
                }
            }
        }
            // One selection ring that slides between previews.
            Rectangle {
                id: selectionRing
                objectName: "overviewSelectionRing"
                readonly property int slot: root.visibleIds.indexOf(root.selWs)
                x: strip.x + root.groupShift + Math.max(0, slot) * (root.tileW + root.gap)
                width: root.tileW
                height: root.tileH
                radius: 12 * root.s
                color: "transparent"
                border.width: 2 * root.s
                border.color: Theme.accent
                opacity: slot >= 0 ? root.groupReveal : 0
                visible: opacity > 0.01
                Behavior on x {
                    enabled: !Flags.reduceMotion && !root.selectionSnap && !groupSlide.running
                    SmoothedAnimation { velocity: -1; duration: Motion.standard }
                }
            }
        }
        Item {
            width: parent.width
            height: 30 * root.s
            Row {
                anchors.right: parent.right
                spacing: 6 * root.s
                Repeater {
                    model: ["chevron_left", "chevron_right", "close"]
                    Rectangle {
                        id: groupAction
                        required property string modelData
                        required property int index
                        width: 30 * root.s; height: width
                        radius: 9 * root.s
                        color: buttonMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.13) : Qt.alpha(Theme.foreground, 0.06)
                        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                        MotionArea {
                            id: buttonMouse
                            accessibleName: groupAction.index === 2 ? I18n.tr("Cerrar") : groupAction.index === 0 ? I18n.tr("Grupo anterior") : I18n.tr("Grupo siguiente")
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: groupAction.index === 2 ? root.requestClose() : root.shiftGroup(groupAction.index === 0 ? -1 : 1)
                        }

                        MaterialIcon {
                            compressWithControl: true
                            interaction: buttonMouse.motion
                            hovered: buttonMouse.containsMouse
                            anchors.centerIn: parent
                            iconName: groupAction.modelData
                            font.pixelSize: 18 * root.s
                            color: Theme.foreground
                        }

                    }
                }
            }
        }
    }
}
