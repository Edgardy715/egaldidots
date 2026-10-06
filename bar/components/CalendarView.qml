pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · CalendarSurface. Calendario mensual rediseñado (nivel caelestia):
 *
 *  · Header Apple: día de la semana + fecha en display grande, reloj vivo,
 *    clima integrado con icono Material + temp + desc.
 *  · Nav de mes con botones circulares que se iluminan al hover.
 *  · Celdas de día pulidas: hoy = acento sólido con glow, seleccionada = anillo,
 *    hover = wash + scale, días de otros meses atenuados.
 *  · Stagger de entrada fila a fila + transición suave al cambiar de mes.
 *  · Sizing robusto: las celdas se adaptan a lo que cabe por ancho/alto (nunca
 *    desbordan la pill).
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginMd

    readonly property var locale: Qt.locale()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()   // 0-based
    property date today: new Date()
    property int selectedDay: today.getDate()

    // re-trigger del stagger de grilla al cambiar de mes
    property int monthEpoch: 0


    // Datos de wttr.in para la vista conjunta de calendario y clima.
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherIcon: "cloud"
    property bool weatherLoading: false
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherWind: ""
    property var forecast: []
    property int weatherView: -1
    property int weatherTarget: -1
    property real weatherHeroOpacity: 1
    readonly property var selectedForecast: weatherView >= 0 && weatherView < forecast.length ? forecast[weatherView] : null

    function selectForecast(index) {
        if (index === weatherTarget) return
        weatherTarget = index
        if (Flags.reduceMotion) { weatherView = index; weatherHeroOpacity = 1; return }
        weatherHeroOpacity = 0
        weatherSwap.restart()
    }
    Timer {
        id: weatherSwap
        interval: Motion.fast
        onTriggered: { root.weatherView = root.weatherTarget; root.weatherHeroOpacity = 1 }
    }
    onClosingChanged: if (closing) { weatherSwap.stop(); weatherHeroOpacity = 1 }

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    function firstOffset(y, m) { return new Date(y, m, 1).getDay() }  // 0=domingo

    readonly property int offset: root.firstOffset(root.viewYear, root.viewMonth)
    readonly property int length: root.daysInMonth(root.viewYear, root.viewMonth)
    readonly property int cellCount: {
        var n = root.offset + root.length
        var rows = Math.ceil(n / 7)
        return rows * 7
    }

    function shiftMonth(d) {
        var m = root.viewMonth + d
        var y = root.viewYear
        if (m < 0) { m = 11; y-- }
        else if (m > 11) { m = 0; y++ }
        root.viewYear = y
        root.viewMonth = m
        root.monthEpoch++
    }

    // ── sizing robusto de la grilla ──
    // cellSize = min(lo que cabe por ancho, lo que cabe por alto) → la grilla
    // SIEMPRE entra en la pill (las celdas se adaptan, nunca desbordan).
    readonly property int gridRows: Math.max(1, Math.ceil(root.cellCount / 7))
    readonly property real cellGap: 5 * root.s
    readonly property real cellSize: {
        var wAvail = (gridHost.width - 6 * root.cellGap) / 7
        var hAvail = (gridHost.height - (root.gridRows - 1) * root.cellGap) / root.gridRows
        return Math.max(10, Math.min(wAvail, hAvail))
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingXl * root.s

        ColumnLayout {
        Layout.preferredWidth: 322 * root.s
        Layout.fillHeight: true
        spacing: Theme.spacingXl * root.s

        // ═══════════ HEADER: fecha grande + reloj + clima ═══════════
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * root.s

            // fecha del día (display grande)
            ColumnLayout {
                spacing: Theme.spacingXxs * root.s
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: root.locale.dayName(root.today.getDay()).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8
                    textFormat: Text.PlainText
                }
                Text {
                    text: root.today.getDate()
                    color: Theme.foreground
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeHeroLg * root.s
                    font.weight: Font.DemiBold
                    lineHeight: 0.95
                }
            }

            Item { Layout.fillWidth: true }

            // Hora junto al calendario; el clima ocupa la columna contigua.
            ColumnLayout {
                spacing: Theme.spacingSm * root.s
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 0
                Layout.maximumWidth: 132 * root.s

                // reloj vivo
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(root.today, Flags.time12h ? "h:mm" : "HH:mm")
                    color: Theme.foreground
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeTitle * root.s
                    font.weight: Font.DemiBold
                }

            }
        }

        // ═══════════ NAV de mes ═══════════
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s

            // prev
            Rectangle {
                id: prevBtn
                Layout.preferredWidth: 28 * root.s; Layout.preferredHeight: 28 * root.s
                radius: height / 2
                color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea { id: prevMa; accessibleName: qsTr("Mes anterior"); anchors.fill: parent; hoverWash: false; onClicked: root.shiftMonth(-1) }

                MaterialIcon {
                    compressWithControl: true
                    interaction: prevMa.motion
                    anchors.centerIn: parent
                    iconName: Icons.iChevronLeft
                    hovered: prevMa.containsMouse
                    color: prevMa.containsMouse ? Theme.accent : Theme.foreground
                    font.pixelSize: Theme.fontSizeTitleLg * root.s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

            }

            Item { Layout.fillWidth: true }

            // mes + año (crossfade al cambiar)
            Text {
                text: root.locale.monthName(root.viewMonth).charAt(0).toUpperCase()
                      + root.locale.monthName(root.viewMonth).slice(1) + " " + root.viewYear
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * root.s
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            // next
            Rectangle {
                id: nextBtn
                Layout.preferredWidth: 28 * root.s; Layout.preferredHeight: 28 * root.s
                radius: height / 2
                color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea { id: nextMa; accessibleName: qsTr("Mes siguiente"); anchors.fill: parent; hoverWash: false; onClicked: root.shiftMonth(1) }

                MaterialIcon {
                    compressWithControl: true
                    interaction: nextMa.motion
                    anchors.centerIn: parent
                    iconName: Icons.iChevronRight
                    hovered: nextMa.containsMouse
                    color: nextMa.containsMouse ? Theme.accent : Theme.foreground
                    font.pixelSize: Theme.fontSizeTitleLg * root.s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderHairline
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }

        // ═══════════ WEEKDAY row ═══════════
        RowLayout {
            Layout.fillWidth: true
            spacing: root.cellGap

            Repeater {
                model: {
                    var out = []
                    for (var i = 0; i < 7; i++)
                        out.push(root.locale.dayName(i).slice(0, 2).toUpperCase())
                    return out
                }
                delegate: Text {
                    required property string modelData
                    required property int index
                    Layout.preferredWidth: root.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: (index === 0 || index === 6) ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }
            }
        }

        // ═══════════ GRID de días ═══════════
        Item {
            id: gridHost
            Layout.fillWidth: true
            Layout.fillHeight: true

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: 7
                spacing: root.cellGap
                width: root.cellSize * 7 + 6 * root.cellGap
                height: root.cellSize * root.gridRows + (root.gridRows - 1) * root.cellGap

                Repeater {
                    model: root.cellCount

                    delegate: StaggerItem {
                        id: cell
                        required property int index
                        readonly property int dayNum: index - root.offset + 1
                        readonly property bool inMonth: index >= root.offset && dayNum <= root.length
                        readonly property bool isToday: inMonth
                            && dayNum === root.today.getDate()
                            && root.viewMonth === root.today.getMonth()
                            && root.viewYear === root.today.getFullYear()
                        readonly property bool selected: inMonth && dayNum === root.selectedDay
                        readonly property bool weekend: (index % 7) === 0 || (index % 7) === 6

                        entered: root.contentReady
                        staggerIndex: Math.floor(index / 7)
                        s: root.s
                        restartKey: root.monthEpoch
                        scaleFrom: 0.97

                        width: root.cellSize
                        height: root.cellSize

                        // pulso al seleccionar: anillo que crece y se asienta
                        property bool justSelected: false
                        onSelectedChanged: if (selected && !justSelected) {
                            justSelected = true
                            selectPulse.restart()
                        }
                        Timer {
                            id: selectPulse
                            interval: Motion.pulse + 60
                            repeat: false
                            onTriggered: cell.justSelected = false
                        }

                        // fondo de la celda
                        Rectangle {
                            anchors.fill: parent
                            radius: root.cellSize * 0.32
                            color: {
                                if (cell.isToday) return Theme.accent
                                if (cell.selected) return Qt.alpha(Theme.accent, Theme.alphaGlow)
                                if (cellMa.containsMouse && cell.inMonth) return Qt.alpha(Theme.accent, Theme.alphaSoft)
                                return cell.weekend && cell.inMonth ? Qt.alpha(Theme.foreground, Theme.alphaGhost) : "transparent"
                            }
                            border.color: {
                                if (cell.isToday) return Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                                if (cell.selected) return Qt.alpha(Theme.accent, Theme.alphaDisabled)
                                if (cellMa.containsMouse && cell.inMonth) return Qt.alpha(Theme.accent, Theme.alphaSelected)
                                return "transparent"
                            }
                            border.width: Theme.borderHairline
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                            // glow suave detrás del "hoy"
                            Rectangle {
                                visible: cell.isToday
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: Theme.borderEmphasis * root.s
                                border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                                BreatheBorder {
                                    glowColor: Theme.accent
                                    width_: 2 * root.s
                                    alphaMin: 0.05
                                    alphaMax: 0.40
                                    period: 2400
                                    s: root.s
                                }
                            }

                            // anillo de selección que respira brevemente
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: Theme.borderEmphasis
                                border.color: Qt.alpha(Theme.accent, cell.justSelected ? 0.6 : 0)
                                scale: cell.justSelected ? 1.08 : 1.0
                                opacity: cell.justSelected ? 1 : 0
                                visible: cell.selected
                                Behavior on scale { Anim { type: Anim.EmphasizedOut } }
                                Behavior on opacity { Anim { type: Anim.EmphasizedOut } }
                            }

                            // número del día
                            Text {
                                scale: cellMa.motion.visualScale
                                transform: Translate { y: -Motion.labelTravel * cellMa.motion.presence }
                                anchors.centerIn: parent
                                text: cell.inMonth ? cell.dayNum : ""
                                color: cell.isToday ? Theme.background
                                              : cell.selected ? Theme.accent
                                                         : (cellMa.containsMouse && cell.inMonth ? Theme.foreground
                                                                                             : (cell.weekend && cell.inMonth ? Qt.alpha(Theme.foreground, Theme.alphaIconSec) : Theme.foreground))
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeBodyLg * root.s
                                font.weight: cell.isToday ? Font.DemiBold : (cell.selected ? Font.DemiBold : Font.Medium)
                                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            }

                            // punto indicador sutil bajo el día actual
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4 * root.s
                                width: 3 * root.s
                                height: 3 * root.s
                                radius: width / 2
                                color: Theme.accent
                                opacity: cell.isToday ? 1 : 0
                            }
                        }

                        MotionArea {
                            id: cellMa
                            accessibleName: qsTr("Seleccionar día %1").arg(cell.dayNum)
                            focusOnTab: false
                            anchors.fill: parent
                            enabled: cell.inMonth
                            hoverWash: false
                            onClicked: if (cell.inMonth) root.selectedDay = cell.dayNum
                        }
                    }
                }
            }
        }
        }

        Rectangle {
            Layout.preferredWidth: Theme.borderHairline
            Layout.fillHeight: true
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingMd * root.s

            Text {
                text: root.selectedForecast ? root.locale.dayName(new Date(root.selectedForecast.date + "T12:00:00").getDay()) : qsTr("Ahora mismo")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeCaption * root.s
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 132 * root.s
                opacity: root.weatherHeroOpacity
                Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
                MaterialIcon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: root.selectedForecast ? root.selectedForecast.icon : root.weatherIcon
                    color: Theme.accent
                    font.pixelSize: 72 * root.s
                    opacity: root.weatherTemp.length ? 1 : 0.4
                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedForecast ? root.selectedForecast.high : (root.weatherTemp || "—°")
                    color: Theme.foreground
                    font.family: Theme.fontDisplay
                    font.pixelSize: 60 * root.s
                    font.weight: Font.Light
                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedForecast ? root.selectedForecast.label : (root.weatherDesc || (root.weatherLoading ? qsTr("Consultando clima…") : qsTr("Clima no disponible")))
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                text: root.selectedForecast ? qsTr("Mínima %1").arg(root.selectedForecast.low) : (root.weatherFeels.length ? qsTr("Sensación térmica %1").arg(root.weatherFeels) : qsTr("Datos del tiempo actual"))
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeCaption * root.s
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: Theme.borderHairline; color: Theme.border }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMd * root.s
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Humedad"); color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s }
                    Text { text: root.weatherHumidity || "—"; color: Theme.foreground; font.family: Theme.fontDisplay; font.pixelSize: Theme.fontSizeBodyLg * root.s }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Viento"); color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s }
                    Text { text: root.weatherWind || "—"; color: Theme.foreground; font.family: Theme.fontDisplay; font.pixelSize: Theme.fontSizeBodyLg * root.s }
                }
            }

            Text {
                text: qsTr("Próximos días")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeCaption * root.s
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.forecast
                delegate: Item {
                    id: forecastRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28 * root.s
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSm * root.s
                        color: root.weatherView === forecastRow.index ? Qt.alpha(Theme.accent, Theme.alphaGlow) : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 5 * root.s
                        anchors.rightMargin: 5 * root.s
                        Text {
                            Layout.preferredWidth: 58 * root.s
                            text: root.locale.dayName(new Date(forecastRow.modelData.date + "T12:00:00").getDay()).slice(0, 3)
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeBody * root.s
                        }
                        MaterialIcon { iconName: forecastRow.modelData.icon; color: Theme.accent; font.pixelSize: Theme.fontSizeBodyLg * root.s }
                        Item { Layout.fillWidth: true }
                        Text { text: forecastRow.modelData.high + "  " + forecastRow.modelData.low; color: Theme.foreground; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeCaption * root.s }
                    }
                    MotionArea {
                        anchors.fill: parent
                        accessibleName: qsTr("Ver pronóstico de %1").arg(forecastRow.modelData.date)
                        hoverWash: false
                        onClicked: root.selectForecast(root.weatherView === forecastRow.index ? -1 : forecastRow.index)
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
