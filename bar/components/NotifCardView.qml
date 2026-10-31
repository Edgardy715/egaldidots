import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import "../"
import "../Singletons"

/** Tarjeta compartida por historial y toast; los iconos usan fallback de imagen, app, tema y glifo genérico.
 */
Item {
    id: card
    // modelData es `required` para forzar que ambos callers (Toast.qml
    // delegate root, NotifsSurface vía StaggerItem) lo provean. ANTES, el
    // delegate del Repeater en NotifsSurface era `StaggerItem` con NotifCard
    // como hijo; la regla de Qt "if the delegate contains required
    // properties, context properties are disabled" rompía la inyección del
    // context property `modelData` del Repeater → el NotifCard required
    // quedaba sin asignar y el delegate no se instanciaba → centro vacío.
    // Fix: el delegate ahora captura modelData en una prop local `notif` y se
    // la pasa al NotifCard explícitamente.
    required property var modelData
    property bool compact: false
    property real s: 1
    property string resolvedIconPath: ""
    signal dismissRequested()
    // History only: the card leaves the history (native close), unlike the
    // toast dismiss, which only hides the popup.
    signal closeRequested()
    signal linkRequested(string link)
    signal actionRequested(var action)
    signal lockRequested(var notification, var owner)
    signal unlockRequested(var notification, var owner)

    readonly property var md: modelData
    readonly property bool critical: md ? md.isCritical : false
    readonly property bool hasImage: md ? (!!md.image && md.image.length > 0) : false
    readonly property bool hasAppIcon: md ? (!!md.appIcon && md.appIcon.length > 0) : false
    readonly property bool isIconUrl: hasImage && ("" + md.image).indexOf("image://icon/") === 0
    // nombre del icono ENCERRADO en image://icon/<name>. Quickshell mete ahí
    // tanto iconos de tema ("input-keyboard") como paths de archivo — cuando el
    // original era un path, el provider lo deja como "image://icon//ruta/a/img"
    // (doble barra): distinguimos ambos casos para no romper el provider.
    readonly property string iconUrlName: isIconUrl ? ("" + md.image).slice(("image://icon/").length) : ""
    // ¿el icono era en realidad un path de archivo (doble barra)?
    readonly property bool isPathIcon: iconUrlName.length > 0 && iconUrlName.charAt(0) === "/"

    readonly property string iconPath: resolvedIconPath
    readonly property real iconSize: (compact ? 34 : 40) * s

    // glyph fallback: heurística del summary (Icons singleton, estilo caelestia)
    readonly property string fallbackGlyph: {
        if (!md) return Icons.iBell
        return Icons.getNotifIcon(md.summary, md.urgency)
    }

    implicitHeight: glass.implicitHeight + 24 * s
    implicitWidth: 320 * s
    Behavior on implicitHeight { Anim { type: Anim.DefaultSpatial } }

    // ---- swipe to dismiss (history) ----
    // Locked to the pointer while dragging; on release it either flies out in
    // the drag direction and then closes, or springs back.
    property real swipeX: 0
    property bool leaving: false
    readonly property real swipeProgress: width > 0 ? Math.min(1, Math.abs(swipeX) / width) : 0
    readonly property bool hovered: cardHover.hovered || closeArea.activeFocus
    opacity: 1 - 0.75 * swipeProgress
    transform: Translate { x: card.swipeX }

    function requestClose(direction) {
        if (leaving || compact) return
        leaving = true
        if (Flags.reduceMotion) { swipeX = 0; closeRequested(); return }
        settle.stop()
        flyOut.to = (direction < 0 ? -1 : 1) * (width + 24 * s)
        flyOut.restart()
    }
    NumberAnimation {
        id: flyOut
        target: card; property: "swipeX"
        duration: Motion.fast; easing.type: Motion.easeStandard
        onFinished: card.closeRequested()
    }
    NumberAnimation {
        id: settle
        target: card; property: "swipeX"; to: 0
        duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 1.1
    }
    HoverHandler { id: cardHover; enabled: !card.compact }
    DragHandler {
        id: swipe
        enabled: !card.compact && !card.leaving
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onActiveChanged: {
            if (active) { settle.stop(); return }
            const fling = Math.abs(centroid.velocity.x) > 900 * card.s
                && Math.sign(centroid.velocity.x) === Math.sign(card.swipeX)
            if (Math.abs(card.swipeX) > card.width * 0.35 || fling) card.requestClose(card.swipeX)
            else if (Flags.reduceMotion) card.swipeX = 0
            else settle.restart()
        }
        onTranslationChanged: if (active) card.swipeX = translation.x
    }

    // ---- expand/collapse ----
    property bool expanded: false
    // Clip only while the height eases: a permanent clip would also trim the
    // close button's enlarged hit area at the glass edge.
    property bool resizing: false
    onExpandedChanged: { resizing = true; resizeHold.restart() }
    Timer { id: resizeHold; interval: Motion.standardLarge + 40; onTriggered: card.resizing = false }
    readonly property int bodyMaxLines: card.expanded ? 20 : 3
    readonly property bool bodyTruncated: card.md && card.md.body
        && card.md.body.length > 120

    Component.onCompleted: if (md) lockRequested(md, card)
    Component.onDestruction: if (md) unlockRequested(md, card)


    // ---- sombra separada del contenido (fix blur en texto) ----
    Rectangle {
        id: bodyShadow
        anchors.fill: parent
        radius: Motion.rTile
        color: "transparent"
        border.width: Theme.borderHairline
        border.color: Theme.border
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * card.s
        }
    }

    // ---- cuerpo de vidrio ----
    Rectangle {
        id: body
        anchors.fill: parent
        radius: Motion.rTile
        border.width: Theme.borderHairline
        border.color: critical ? Qt.alpha(Theme.accent, Theme.alphaCritical) : Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.glassAlpha) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.glassAlpha) }
        }

        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 1 * s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.82; height: 1.2 * s; radius: height / 2
            color: Theme.sheen
        }

        InnerGlow {
            anchors.fill: parent
            opacity: critical ? 0.72 : 0
        }

        // glow crítico medio (borde respira)
        Rectangle {
            id: glowMid
            anchors.fill: parent; radius: body.radius; color: "transparent"
            border.width: Theme.borderEmphasis * card.s
            border.color: Qt.alpha(Theme.accent, 0)
            visible: critical
            SequentialAnimation {
                running: critical && card.visible && !Flags.reduceMotion; loops: Animation.Infinite
                ColorAnimation { target: glowMid.border; property: "color"; from: Qt.alpha(Theme.accent, Theme.alphaTransparent); to: Qt.alpha(Theme.accent, Theme.alphaSelected); duration: Math.round(Motion.breathe * 0.6); easing.type: Motion.easeBreathe }
                ColorAnimation { target: glowMid.border; property: "color"; from: Qt.alpha(Theme.accent, Theme.alphaSelected); to: Qt.alpha(Theme.accent, Theme.alphaTransparent); duration: Math.round(Motion.breathe * 0.6); easing.type: Motion.easeBreathe }
                PauseAnimation { duration: Math.round(400 * Motion.mult) }
            }
        }

        // hover wash: the single hover layer for both toast and history
        Rectangle {
            anchors.fill: parent; radius: body.radius
            color: Theme.foreground
            opacity: (card.compact ? ma.containsMouse : card.hovered) ? 0.07 : 0
            Behavior on opacity { Anim { type: Anim.FastEffects } }
        }
    }

    // Toast: the whole card dismisses. History: hover only, presses go to the
    // swipe and to the controls inside.
    MotionArea {
        id: ma
        accessibleName: card.compact ? qsTr("Cerrar notificación") : ""
        acceptedButtons: card.compact ? Qt.LeftButton : Qt.NoButton
        hoverWash: false
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.compact ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.compact && card.md) card.dismissRequested()
    }

    // ---- contenido ----
    ColumnLayout {
        id: glass
        anchors.fill: parent
        anchors.margins: 12 * s
        spacing: Theme.spacingMd * s
        z: 1
        // The card height eases on expand/collapse; the new lines must not
        // spill past the glass while it catches up.
        clip: !card.compact && card.resizing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s

            // ---- slot de icono ----
            Item {
                id: iconSlot
                Layout.preferredWidth: card.iconSize
                Layout.preferredHeight: card.iconSize

                // círculo de tinte
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: card.critical ? Qt.alpha(Theme.accentStrong, Theme.alphaEmphasis) : Qt.alpha(Theme.accent, Theme.alphaChip) }
                        GradientStop { position: 1.0; color: card.critical ? Qt.alpha(Theme.accentStrong, Theme.alphaGlow) : Qt.alpha(Theme.accent, Theme.alphaSoft) }
                    }
                    border.color: card.critical ? Qt.alpha(Theme.accentStrong, Theme.alphaCritical) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                    border.width: Theme.borderHairline
                }

                // ruta 1: image://icon/<name> → IconImage de Quickshell. Sólo cuando
                // el icono es un nombre de tema real (NO un path en doble barra).
                IconImage {
                    id: iconImg
                    anchors.centerIn: parent
                    width: card.iconSize * 0.62; height: card.iconSize * 0.62
                    source: card.isIconUrl && !card.isPathIcon ? card.md.image : ""
                    visible: card.isIconUrl && !card.isPathIcon && status === IconImage.Ready
                }
                // ruta 2: path de archivo real (artwork de Spotify, screenshot, etc.)
                Image {
                    id: img
                    anchors.centerIn: parent
                    width: card.iconSize * 0.62; height: card.iconSize * 0.62
                    source: card.iconPath.length > 0 ? card.iconPath : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false; asynchronous: true
                    visible: card.iconPath.length > 0 && status === Image.Ready
                }
                // ruta 3: fallback glyph (Material Symbols) — cuando ninguna ruta
                // anterior resolvió. Cubre iconos de tema inexistentes y resúmenes
                // sin icono (teclado, screenshot sin archivo, etc.).
                MaterialIcon {
                    compressWithControl: true
                    interaction: ma.motion
                    anchors.centerIn: parent
                    visible: (card.iconPath.length === 0 || img.status !== Image.Ready)
                             && iconImg.status !== IconImage.Ready
                    iconName: card.fallbackGlyph
                    color: card.critical ? Theme.accentStrong : Theme.accent
                    font.pixelSize: card.iconSize * 0.5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXs * s

                // título (summary) + chip de app
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd * s

                    Text {
                        scale: ma.motion.visualScale
                        transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                        Layout.fillWidth: true
                        text: card.md.summary || (card.md.appName || "")
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: (card.compact ? 12 : 13) * card.s
                        font.weight: Font.Medium
                        font.letterSpacing: -0.05 * card.s
                        elide: Text.ElideRight
                    }

                    // badge de urgencia para críticas
                    Rectangle {
                        visible: card.critical && !card.compact
                        Layout.preferredWidth: urgTxt.implicitWidth + 10 * s
                        Layout.preferredHeight: 16 * s
                        Layout.alignment: Qt.AlignVCenter
                        radius: height / 2
                        color: Qt.alpha(Theme.accentStrong, Theme.alphaChip)
                        border.color: Qt.alpha(Theme.accentStrong, Theme.alphaDisabled); border.width: Theme.borderHairline
                        Text {
                            scale: ma.motion.visualScale
                            transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                            id: urgTxt
                            anchors.centerIn: parent
                            text: "URGENTE"
                            color: Theme.accentStrong
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * card.s
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                    }

                    // close (history): appears with hover or keyboard focus
                    Rectangle {
                        id: closeButton
                        visible: !card.compact
                        Layout.preferredWidth: 20 * card.s
                        Layout.preferredHeight: 20 * card.s
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        opacity: card.hovered || closeArea.containsMouse ? 1 : 0
                        scale: (0.86 + 0.14 * opacity) * closeArea.motion.visualScale
                        color: closeArea.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: Icons.iClose
                            color: closeArea.containsMouse ? Theme.foreground : Theme.iconSecondary
                            font.pixelSize: 13 * card.s
                        }
                        MotionArea {
                            id: closeArea
                            objectName: "notificationClose"
                            anchors.fill: parent
                            anchors.margins: -4 * card.s
                            enabled: !card.compact && !card.leaving
                            feedbackEnabled: false
                            accessibleName: qsTr("Descartar notificación")
                            onClicked: card.requestClose(1)
                        }
                    }
                }

                // app · tiempo
                Text {
                    scale: ma.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: {
                        var app = card.md.appName || ""
                        return app.length > 0 ? (app + "  ·  " + card.md.timeStr) : card.md.timeStr
                    }
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * card.s
                    font.letterSpacing: 0.1 * card.s
                    elide: Text.ElideRight
                }

                // body con expand/collapse
                Text {
                    scale: ma.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                    id: bodyText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.md.body
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * card.s
                    textFormat: card.md.bodyIsRich ? Text.RichText : Text.PlainText
                    wrapMode: card.compact ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: card.compact ? 1 : card.bodyMaxLines
                    elide: Text.ElideRight
                    onLinkActivated: function(link) {
                        if (card.compact) return
                        card.linkRequested(link)
                    }
                }

                // expand toggle
                Text {
                    scale: ma.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                    Layout.fillWidth: true
                    visible: !card.compact && card.bodyTruncated
                    text: card.expanded ? qsTr("mostrar menos") : "···"
                    color: Qt.alpha(Theme.accent, Theme.alphaIconSec)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * card.s
                    font.weight: Font.Medium
                    MotionArea {
                        accessibleName: card.expanded ? qsTr("Mostrar menos") : qsTr("Expandir notificación")
                        anchors.fill: parent
                        anchors.margins: -4 * s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.expanded = !card.expanded
                    }
                }
            }
        }

        // actions (solo full mode)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * s
            visible: !card.compact && card.md && card.md.actions.length > 0
            Repeater {
                model: card.md ? card.md.actions : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28 * card.s
                    radius: Theme.radiusSm * card.s
                    color: act.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                    border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft); border.width: Theme.borderHairline
                    transformOrigin: Item.Center
                    Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                    MotionArea {
                        id: act
                        objectName: "notificationAction"
        accessibleName: modelData.text || qsTr("Acción de notificación")
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData) card.actionRequested(modelData)
                    }

                    Text {
                        scale: act.motion.visualScale
                        transform: Translate { y: -Motion.labelTravel * act.motion.presence }
                        anchors.centerIn: parent
                        text: modelData.text || ""
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSmall * card.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

}
            }
        }
    }
}
