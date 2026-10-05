import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../"
import "../Singletons"

/**
 * Isla · NotifCard. Delegate de vidrio compartido por el centro (NotifsSurface,
 * compact:false) y el toast (Toast.qml, compact:true). Mismo cuerpo que la pill:
 * gradiente cardTop→cardBot + borde + sheen + sombra separada del contenido.
 *
 * Iconos: prioriza image (preview de la notif, ej. artwork de Spotify), luego
 * appIcon (icono de la app via Quickshell.iconPath), luego image://icon/ (icono
 * temático via IconImage del NotificationServer), y si nada → glyph por appName.
 *
 * Urgencia Critical → borde accent y luz interior; el borde respira.
 * Hover wash + click del compact oculta el toast (popup=false). Actions (full)
 * en fila con wash/escala. Cero springs.
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

    readonly property string iconPath: {
        if (!md) return ""
        if (hasAppIcon) {
            var raw = md.appIcon
            if (!Quickshell.iconPath(raw, true)) {
                var base = raw.replace(/\.desktop$/, "")
                if (base !== raw) raw = base
            }
            if (Quickshell.iconPath(raw, true)) return Quickshell.iconPath(raw)
        }
        if (md.appName && md.appName.length) {
            var entry = DesktopEntries.heuristicLookup(md.appName)
            if (entry && entry.icon && entry.icon.length) {
                var p = Quickshell.iconPath(entry.icon, true)
                if (p) return p
            }
        }
        // icono de path real: bien md.image directo, bien el path que venía
        // dentro de image://icon//... (screenshot de hyprshot, etc.)
        if (hasImage && !isIconUrl) {
            var s = "" + md.image
            if (s.indexOf("/") === 0 || s.indexOf("file://") === 0 || s.indexOf("http") === 0)
                return s
        }
        if (isPathIcon) return iconUrlName
        return ""
    }
    readonly property real iconSize: (compact ? 34 : 40) * s

    // glyph fallback: heurística del summary (Icons singleton, estilo caelestia)
    readonly property string fallbackGlyph: {
        if (!md) return Icons.iBell
        return Icons.getNotifIcon(md.summary, md.urgency)
    }

    implicitHeight: glass.implicitHeight + 24 * s
    implicitWidth: 320 * s
    Behavior on implicitHeight { Anim { type: Anim.DefaultSpatial } }

    // ---- expand/collapse ----
    property bool expanded: false
    readonly property int bodyMaxLines: card.expanded ? 20 : 3
    readonly property bool bodyTruncated: card.md && card.md.body
        && card.md.body.length > 120

    Component.onCompleted: if (md) md.lock(card)
    Component.onDestruction: if (md) md.unlock(card)

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
                ColorAnimation { target: glowMid.border; property: "color"; from: Qt.alpha(Theme.accent, Theme.alphaTransparent); to: Qt.alpha(Theme.accent, Theme.alphaSelected); duration: 1800; easing.type: Easing.InOutSine }
                ColorAnimation { target: glowMid.border; property: "color"; from: Qt.alpha(Theme.accent, Theme.alphaSelected); to: Qt.alpha(Theme.accent, Theme.alphaTransparent); duration: 1800; easing.type: Easing.InOutSine }
                PauseAnimation { duration: Math.round(400 * Motion.mult) }
            }
        }

        // hover wash
        Rectangle {
            anchors.fill: parent; radius: body.radius
            color: Qt.alpha(Theme.foreground, ma.containsMouse ? 0.08 : 0.0)
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }
    }

    // ---- hover + click feedback ----
    Rectangle {
        anchors.fill: parent; radius: Motion.rTile
        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        z: -1
    }

    MotionArea {
        id: ma
        enabled: card.compact
        accessibleName: qsTr("Cerrar notificación")
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.compact ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.compact && card.md) card.md.popup = false
    }

    // ---- contenido ----
    ColumnLayout {
        id: glass
        anchors.fill: parent
        anchors.margins: 12 * s
        spacing: Theme.spacingMd * s
        z: 1

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
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeCaption * card.s
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
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
                        Qt.openUrlExternally(link)
                        if (card.md) card.md.popup = false
                    }
                }

                // expand toggle
                Text {
                    scale: ma.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * ma.motion.presence }
                    Layout.fillWidth: true
                    visible: !card.compact && card.bodyTruncated
                    text: card.expanded ? "mostrar menos" : "···"
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
        accessibleName: modelData.text || qsTr("Acción de notificación")
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData && typeof modelData.invoke === "function") modelData.invoke()
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
