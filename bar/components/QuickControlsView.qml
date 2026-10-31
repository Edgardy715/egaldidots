pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"

// Centro de control: dos mosaicos de acción (estado de un vistazo), un
// deslizador de brillo táctil y el selector de perfil de energía.
Item {
    id: root
    property real s: 1
    property bool contentReady: false
    property bool showBrightness: false
    property bool showProfile: true
    // What the controls need, so the glass does not reserve room for absent sections.
    readonly property real contentHeight: col.implicitHeight
    property real brightnessPercent: 0
    property bool brightnessLastWriteOk: true
    property bool keepAwakeEnabled: false
    property string keepAwakeElapsedTime: "--:--"
    property string activeProfile: "balanced"
    property bool profileBusy: false
    property string profileError: ""
    property var profiles: ["performance", "balanced", "power-saver"]

    signal requestPage(string name)
    signal keepAwakeToggleRequested()
    signal brightnessSetPercent(real percent)
    signal brightnessStepRequested(real amount)
    signal profileSelected(string profile)

    function profileIndex(): int {
        return root.profiles ? root.profiles.indexOf(root.activeProfile) : 0
    }
    readonly property bool profileAvailable: root.profileIndex() >= 0

    clip: true

    // evita que la rueda llegue al control de volumen de la pill
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {}
    }

    // Mosaico de acción: icono en círculo arriba, título y estado abajo.
    // Activo = círculo de acento relleno y estado en acento; el fondo sólo se tiñe.
    component QuickTile: Item {
        id: tile
        property string iconName: ""
        property string title: ""
        property string detail: ""
        property bool active: false
        property bool navigates: false
        property alias hit: tileHit
        signal activated()

        implicitHeight: 92 * root.s

        Rectangle {
            id: tileFace
            anchors.fill: parent
            scale: tileHit.motion.visualScale
            radius: Theme.radiusXxl * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            border.width: Theme.liquid ? 0 : Theme.borderHairline
            border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)

            // El estado activo nace de la gota del icono y llena el mosaico.
            LiquidFill {
                id: tileFill
                objectName: "tileLiquid"
                active: tile.active
                originX: tileBadge.x; originY: tileBadge.y
                originSize: tileBadge.width
                cornerRadius: tileFace.radius
            }

            Rectangle {
                id: tileBadge
                x: 12 * root.s; y: 12 * root.s
                width: 34 * root.s; height: width
                radius: width / 2
                color: tileFill.covered ? Qt.alpha(Theme.stateContent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: tile.iconName
                    interaction: tileHit.motion
                    compressWithControl: true
                    color: tileFill.covered ? Theme.stateContent : Theme.foreground
                    font.pixelSize: 19 * root.s
                    Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                }
            }

            MaterialIcon {
                visible: tile.navigates
                anchors.right: parent.right; anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: tileBadge.verticalCenter
                iconName: Icons.iChevronRight
                color: tileFill.covered ? Theme.stateContentSecondary : Theme.iconSecondary
                font.pixelSize: 18 * root.s
                transform: Translate { x: 2 * root.s * tileHit.motion.presence }
            }

            Column {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12 * root.s
                spacing: Theme.spacingXs * root.s
                Text {
                    width: parent.width
                    text: tile.title
                    color: tileFill.covered ? Theme.stateContent : Theme.foreground
                    Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                AnimatedLabel {
                    width: parent.width
                    value: tile.detail
                    color: tileFill.covered ? Theme.stateContentSecondary : Theme.iconSecondary
                    font.family: Theme.font; font.features: Theme.fontNumeric
                    font.pixelSize: Theme.fontSizeLabel * root.s
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                }
            }
        }

        MotionArea {
            id: tileHit
            anchors.fill: parent
            feedbackRadius: tileFace.radius
            hoverWash: true
            onClicked: tile.activated()
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.spacingXl * root.s

        // ════════════════════ HEADER ════════════════════
        SurfaceHeader {
            Layout.fillWidth: true
            title: qsTr("Ajustes rápidos")
            s: root.s
            trailing: Component {
                Rectangle {
                    implicitWidth: appearanceRow.implicitWidth + 22 * root.s
                    implicitHeight: 30 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                    border.width: Theme.liquid ? 0 : Theme.borderHairline
                    border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)
                    scale: appearanceHit.motion.visualScale
                    Row {
                        id: appearanceRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "palette"
                            interaction: appearanceHit.motion
                            color: Theme.accent
                            font.pixelSize: Theme.fontSizeBodyLg * root.s
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Apariencia")
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeSmall * root.s
                            font.weight: Font.Medium
                        }
                    }
                    MotionArea {
                        id: appearanceHit
                        objectName: "appearanceAction"
                        anchors.fill: parent
                        accessibleName: qsTr("Abrir ajustes de apariencia")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPage("appearance")
                    }
                }
            }
        }

        // ════════════════════ MOSAICOS ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            implicitHeight: tiles.implicitHeight
            staggerIndex: 0
            entered: root.contentReady
            s: root.s

            RowLayout {
                id: tiles
                anchors.fill: parent
                spacing: Theme.spacingLg * root.s

                QuickTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    iconName: Icons.iCoffee
                    title: qsTr("Mantener activa")
                    detail: root.keepAwakeEnabled ? qsTr("Activa · %1").arg(root.keepAwakeElapsedTime) : qsTr("Desactivada")
                    active: root.keepAwakeEnabled
                    hit.objectName: "keepAwakeToggle"
                    hit.accessibleName: qsTr("Mantener despierto")
                    hit.Accessible.role: Accessible.CheckBox
                    hit.Accessible.checkable: true
                    hit.Accessible.checked: root.keepAwakeEnabled
                    onActivated: root.keepAwakeToggleRequested()
                }

                QuickTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    iconName: "timer"
                    title: qsTr("Actividades")
                    detail: qsTr("Enfoque y grabación")
                    navigates: true
                    hit.objectName: "openFocus"
                    hit.accessibleName: qsTr("Abrir enfoque y grabación")
                    onActivated: root.requestPage("focus")
                }
            }
        }

        // ════════════════════ BRILLO ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 1
            entered: root.contentReady && root.showBrightness
            s: root.s
            visible: root.showBrightness

            GlassCard {
                anchors.fill: parent
                s: root.s
                implicitHeight: briBody.implicitHeight + 24 * root.s

                ColumnLayout {
                    id: briBody
                    anchors.fill: parent
                    anchors.margins: 12 * root.s
                    spacing: Theme.spacingLg * root.s

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBaseline
                            text: qsTr("Brillo")
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.DemiBold
                        }
                        // La cifra es el dato: grande y tabular, sigue al arrastre.
                        Text {
                            objectName: "brightnessPercent"
                            Layout.alignment: Qt.AlignBaseline
                            text: Math.round(brightnessSlider.dragging || brightnessSlider.holding ? brightnessSlider.dragValue * 100 : root.brightnessPercent)
                            color: Theme.foreground
                            font.family: Theme.fontDisplay; font.features: Theme.fontNumeric
                            font.pixelSize: Theme.fontSizeDisplayLg * root.s; font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignBaseline
                            Layout.leftMargin: -parent.spacing + 1 * root.s
                            text: "%"
                            color: Theme.iconSecondary
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.DemiBold
                        }
                    }

                    // Deslizador grueso estilo centro de control: el sol vive dentro
                    // de la pista y cambia de tinta cuando el relleno lo alcanza.
                    Slider {
                        id: brightnessSlider
                        objectName: "brightnessSlider"
                        Layout.fillWidth: true
                        Layout.preferredHeight: height
                        value: root.brightnessPercent / 100
                        height_: 36
                        knob: false
                        s: root.s
                        // En 0 % el relleno es una gota con el sol dentro; al subir se estira.
                        minFill: Theme.liquid ? height : 0
                        enabled: root.showBrightness
                        activeFocusOnTab: enabled
                        Accessible.role: Accessible.Slider
                        Accessible.name: qsTr("Brillo")
                        Accessible.description: Math.round(root.brightnessPercent) + "%"
                        Accessible.onIncreaseAction: if (enabled && visible) root.brightnessStepRequested(5)
                        Accessible.onDecreaseAction: if (enabled && visible) root.brightnessStepRequested(-5)
                        Keys.onLeftPressed: if (enabled && visible) root.brightnessStepRequested(-5)
                        Keys.onRightPressed: if (enabled && visible) root.brightnessStepRequested(5)
                        onSliderLiveChanged: (v) => root.brightnessSetPercent(v * 100)

                        MaterialIcon {
                            readonly property bool covered: brightnessSlider.minFill > 0 || brightnessSlider.shownValue * brightnessSlider.width > x + width
                            x: (brightnessSlider.height - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: root.brightnessPercent < 40 ? "brightness_low" : "brightness_high"
                            color: covered ? (Theme.liquid ? Theme.stateContent : Theme.primaryContent) : Theme.iconSecondary
                            font.pixelSize: 18 * root.s
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: "transparent"
                            border.color: Theme.accent
                            border.width: parent.activeFocus ? Theme.borderHairline : 0
                            Accessible.ignored: true
                        }
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: (event) => {
                                if (event.angleDelta.y !== 0) root.brightnessStepRequested(event.angleDelta.y > 0 ? 5 : -5)
                            }
                        }
                    }

                    Text {
                        objectName: "brightnessWriteError"
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight * opacity
                        Layout.topMargin: -Theme.spacingLg * root.s * (1 - opacity)
                        visible: opacity > 0.01
                        text: qsTr("Sin permiso para cambiar el brillo")
                        color: Theme.accentStrong
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s
                        clip: true
                        opacity: root.brightnessLastWriteOk ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        // ════════════════════ PERFIL DE ENERGÍA ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 2
            entered: root.contentReady && root.showProfile
            visible: root.showProfile
            s: root.s

            GlassCard {
                anchors.fill: parent
                s: root.s
                implicitHeight: powBody.implicitHeight + 24 * root.s

                ColumnLayout {
                    id: powBody
                    anchors.fill: parent
                    anchors.margins: 12 * root.s
                    spacing: Theme.spacingLg * root.s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd * root.s
                        Text {
                            text: qsTr("Energía")
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.DemiBold
                        }
                        AnimatedLabel {
                            objectName: "powerProfileSummary"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            value: {
                                if (root.activeProfile === "performance") return "Máximo rendimiento · más consumo"
                                if (root.activeProfile === "balanced") return "Equilibrio · recomendado"
                                if (root.activeProfile === "power-saver") return "Máximo ahorro · menos consumo"
                                return root.profileError.length ? root.profileError : qsTr("Perfil no disponible")
                            }
                            color: root.profileAvailable ? Theme.iconSecondary : Theme.accentStrong
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s
                        }
                    }

                    // Un fallo al aplicar se explica aquí; si no hay perfil, ya lo dice el resumen.
                    Text {
                        objectName: "powerProfileError"
                        visible: root.profileError.length > 0 && root.profileAvailable
                        text: root.profileError
                        color: Theme.accentStrong
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    // selector segmentado animado
                    Item {
                        id: segSelector
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38 * root.s
                        opacity: root.profileAvailable ? (root.profileBusy ? 0.7 : 1) : Theme.alphaDisabled
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.liquid ? 0 : Theme.borderHairline; border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)
                        }

                        // Gota de selección: se estira hacia la opción nueva y se recoge al llegar.
                        LiquidSelection {
                            objectName: "profileSelection"
                            readonly property real segW: segSelector.width / 3
                            visible: root.profileAvailable && root.profileIndex() >= 0
                            targetX: 3 * root.s + Math.max(0, root.profileIndex()) * segW
                            targetY: 3 * root.s
                            targetWidth: segW - 6 * root.s
                            targetHeight: segSelector.height - 6 * root.s
                            immediate: !root.contentReady
                            radius: height / 2
                            color: Theme.liquid ? Theme.stateFill : Theme.accent
                            volume: true
                        }

                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: root.profiles
                                delegate: Item {
                                    id: profileOption
                                    required property string modelData
                                    readonly property bool current: root.activeProfile === modelData
                                    width: parent.width / 3
                                    height: parent.height
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingSm * root.s
                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            iconName: profileOption.modelData === "performance" ? "bolt"
                                                : profileOption.modelData === "balanced" ? "balance" : "eco"
                                            interaction: profileHit.motion
                                            color: profileOption.current ? Theme.stateContent : Theme.iconSecondary
                                            font.pixelSize: 15 * root.s
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        }
                                        Text {
                                            id: profileLabel
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: profileOption.modelData === "performance" ? "Rendimiento"
                                                : profileOption.modelData === "balanced" ? "Balanceado"
                                                : profileOption.modelData === "power-saver" ? "Ahorro" : profileOption.modelData
                                            color: profileOption.current ? Theme.stateContent : Theme.foreground
                                            font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s
                                            font.weight: profileOption.current ? Font.DemiBold : Font.Medium
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        }
                                    }
                                    MotionArea {
                                        id: profileHit
                                        objectName: "profile-" + profileOption.modelData
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        accessibleName: qsTr("Perfil de energía: %1").arg(profileLabel.text)
                                        Accessible.role: Accessible.RadioButton
                                        Accessible.checked: profileOption.current
                                        enabled: !root.profileBusy
                                        feedbackRadius: height / 2
                                        hoverWash: !profileOption.current
                                        onClicked: root.profileSelected(profileOption.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
