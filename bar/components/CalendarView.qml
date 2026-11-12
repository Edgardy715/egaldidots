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

    // Fechas y controles comparten el idioma traducible de la interfaz.
    readonly property var dayNames: [I18n.tr("domingo"), I18n.tr("lunes"), I18n.tr("martes"),
        I18n.tr("miércoles"), I18n.tr("jueves"), I18n.tr("viernes"), I18n.tr("sábado")]
    readonly property var monthNames: [I18n.tr("enero"), I18n.tr("febrero"), I18n.tr("marzo"),
        I18n.tr("abril"), I18n.tr("mayo"), I18n.tr("junio"), I18n.tr("julio"), I18n.tr("agosto"),
        I18n.tr("septiembre"), I18n.tr("octubre"), I18n.tr("noviembre"), I18n.tr("diciembre")]
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()   // 0-based
    property date today: Regional.now()
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
    property string weatherError: ""
    property string weatherLocation: ""
    property string weatherUpdated: ""
    signal refreshWeatherRequested()
    property var forecast: []
    // Escala común de la semana para las barras de rango del pronóstico.
    readonly property var forecastRange: {
        let lo = Infinity, hi = -Infinity
        for (const day of forecast) {
            const l = parseInt(day.low), h = parseInt(day.high)
            if (!isNaN(l)) lo = Math.min(lo, l)
            if (!isNaN(h)) hi = Math.max(hi, h)
        }
        return isFinite(lo) && isFinite(hi) && hi > lo ? { lo: lo, span: hi - lo } : null
    }
    property bool hasMedia: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArtUrl: ""
    signal mediaRequested()
    onForecastChanged: if (weatherView >= forecast.length || weatherTarget >= forecast.length) { weatherSwap.stop(); weatherView = -1; weatherTarget = -1; weatherHeroOpacity = 1 }
    property int weatherView: -1
    property int weatherTarget: -1
    property real weatherHeroOpacity: 1
    readonly property var selectedForecast: weatherView >= 0 && weatherView < forecast.length ? forecast[weatherView] : null

    function selectForecast(index) {
        index = index >= 0 && index < forecast.length ? index : -1
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
    onClosingChanged: if (closing) { weatherSwap.stop(); weatherTarget = weatherView; weatherHeroOpacity = 1 }

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    // Leading blank cells before day 1, for the region's first day of the week.
    function firstOffset(y, m) { return (new Date(y, m, 1).getDay() - Regional.weekStart + 7) % 7 }

    readonly property int offset: root.firstOffset(root.viewYear, root.viewMonth)
    readonly property int length: root.daysInMonth(root.viewYear, root.viewMonth)
    readonly property int cellCount: {
        var n = root.offset + root.length
        var rows = Math.ceil(n / 7)
        return rows * 7
    }

    // Last navigation direction: the title rolls and the grid slides with it.
    property int monthDir: 1
    property bool selectionSnap: false
    function shiftMonth(d) {
        root.monthDir = d < 0 ? -1 : 1
        root.selectionSnap = true
        var m = root.viewMonth + d
        var y = root.viewYear
        if (m < 0) { m = 11; y-- }
        else if (m > 11) { m = 0; y++ }
        root.viewYear = y
        root.viewMonth = m
        root.monthEpoch++
        root.selectionSnap = false
        if (!Flags.reduceMotion) monthSlide.restart()
    }
    property real gridShift: 0
    NumberAnimation {
        id: monthSlide
        target: root; property: "gridShift"
        from: root.monthDir * 18 * root.s; to: 0
        duration: Motion.standard; easing.type: Motion.easeStandard
    }
    readonly property int selectedIndex: root.selectedDay >= 1 && root.selectedDay <= root.length
        ? root.offset + root.selectedDay - 1 : -1
    // Con Superficies líquidas el estiramiento de la gota ya es la respuesta.
    onSelectedDayChanged: if (!Flags.reduceMotion && !selectionSnap && !Theme.liquid) selectionPop.restart()

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
                    objectName: "calendarTodayWeekday"
                    text: root.dayNames[root.today.getDay()].toUpperCase()
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
                Layout.preferredWidth: Math.max(32, 36 * root.s); Layout.preferredHeight: Math.max(32, 36 * root.s)
                radius: height / 2
                color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.liquid ? 0 : Theme.borderHairline
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea { id: prevMa; objectName: "calendarPreviousMonth"; accessibleName: I18n.tr("Mes anterior"); anchors.fill: parent; hoverWash: false; onClicked: root.shiftMonth(-1) }

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

            // mes + año: rueda en la dirección de la navegación
            CrossfadeLabel {
                objectName: "calendarMonthTitle"
                Layout.fillWidth: true
                value: root.monthNames[root.viewMonth].charAt(0).toUpperCase()
                      + root.monthNames[root.viewMonth].slice(1) + " " + root.viewYear
                swapTravel: root.monthDir * 6 * root.s * Motion.labelTravel
                horizontalAlignment: Text.AlignHCenter
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * root.s
                font.weight: Font.DemiBold
            }

            // next
            Rectangle {
                id: nextBtn
                Layout.preferredWidth: Math.max(32, 36 * root.s); Layout.preferredHeight: Math.max(32, 36 * root.s)
                radius: height / 2
                color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.liquid ? 0 : Theme.borderHairline
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea { id: nextMa; objectName: "calendarNextMonth"; accessibleName: I18n.tr("Mes siguiente"); anchors.fill: parent; hoverWash: false; onClicked: root.shiftMonth(1) }

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
                        out.push(root.dayNames[(i + Regional.weekStart) % 7].slice(0, 2).toUpperCase())
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

            Item {
                id: gridLayer
                anchors.centerIn: parent
                width: root.cellSize * 7 + 6 * root.cellGap
                height: root.cellSize * root.gridRows + (root.gridRows - 1) * root.cellGap
                transform: Translate { x: root.gridShift }

            // One selection that travels between days instead of each cell
            // lighting up on its own; it snaps when the month changes. Liquid
            // surfaces let it stretch toward the new day and gather on arrival.
            LiquidSelection {
                id: selectionMark
                objectName: "calendarSelectionMark"
                // Keep the last valid slot when the day falls outside the month
                // (31 → a 30-day month) so it fades in place instead of jumping.
                property int slot: 0
                readonly property int col: slot % 7
                readonly property int row: Math.floor(slot / 7)
                // Arrive with the selected day's own staggered reveal.
                readonly property Item cell: root.selectedIndex >= 0 && dayCells.count > root.selectedIndex ? dayCells.itemAt(root.selectedIndex) : null
                targetX: col * (root.cellSize + root.cellGap)
                targetY: row * (root.cellSize + root.cellGap)
                targetWidth: root.cellSize
                targetHeight: root.cellSize
                immediate: root.selectionSnap
                radius: Math.min(width, height) * 0.32
                color: Theme.liquid ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.accent, Theme.alphaGlow)
                border.color: Qt.alpha(Theme.accent, Theme.alphaDisabled)
                border.width: Theme.liquid ? 0 : Theme.borderHairline
                opacity: cell ? cell.progress : 0
                visible: opacity > 0.01
                Binding on slot { when: root.selectedIndex >= 0; value: root.selectedIndex; restoreMode: Binding.RestoreNone }
                SequentialAnimation {
                    id: selectionPop
                    NumberAnimation { target: selectionMark; property: "scale"; to: 1.06; duration: Motion.press; easing.type: Motion.easeStandard }
                    NumberAnimation { target: selectionMark; property: "scale"; to: 1; duration: Motion.standard; easing.type: Easing.OutBack }
                }
            }

            Grid {
                id: grid
                anchors.fill: parent
                columns: 7
                spacing: root.cellGap

                Repeater {
                    id: dayCells
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

                        // fondo de la celda
                        Rectangle {
                            anchors.fill: parent
                            radius: root.cellSize * 0.32
                            color: {
                                if (cell.isToday) return Theme.liquid ? Theme.stateFill : Theme.accent
                                if (cell.selected) return "transparent"
                                if (cellMa.containsMouse && cell.inMonth) return Qt.alpha(Theme.accent, Theme.alphaSoft)
                                // El fin de semana se distingue sólo por tinta: un fondo
                                // propio volvía la rejilla una pared de bloques.
                                return "transparent"
                            }
                            border.color: {
                                if (cell.isToday) return Theme.liquid ? "transparent" : Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                                if (cell.selected) return "transparent"
                                if (cellMa.containsMouse && cell.inMonth) return Qt.alpha(Theme.accent, Theme.alphaSelected)
                                return "transparent"
                            }
                            border.width: Theme.borderHairline
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            gradient: Theme.liquid && cell.isToday ? todayVolume : null
                            property Gradient todayVolume: Gradient {
                                GradientStop { position: 0; color: Theme.stateFillLight }
                                GradientStop { position: 1; color: Theme.stateFill }
                            }

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

                            // número del día
                            Text {
                                scale: cellMa.motion.visualScale
                                transform: Translate { y: -Motion.labelTravel * cellMa.motion.presence }
                                anchors.centerIn: parent
                                text: cell.inMonth ? cell.dayNum : ""
                                color: cell.isToday ? (Theme.liquid ? Theme.stateContent : Theme.primaryContent)
                                              : cell.selected ? Theme.accent
                                                         : (cellMa.containsMouse && cell.inMonth ? Theme.foreground
                                                                                             : (cell.weekend && cell.inMonth ? Qt.alpha(Theme.foreground, Theme.alphaIconSec) : Theme.foreground))
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeBodyLg * root.s
                                font.weight: cell.isToday ? Font.DemiBold : Font.Medium
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
                            accessibleName: I18n.tr("Seleccionar día %1").arg(cell.dayNum)
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
        }

        Rectangle {
            Layout.preferredWidth: Theme.borderHairline
            Layout.fillHeight: true
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }

        ColumnLayout {
            Layout.preferredWidth: 220 * root.s
            Layout.minimumWidth: 180 * root.s
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.hasMedia ? 8 * root.s : 0

            Flickable {
                id: weatherScroll
                objectName: "calendarWeather"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: weatherColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                id: weatherColumn
                width: weatherScroll.width
                spacing: 10 * root.s
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("Clima")
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: !!root.selectedForecast
                        Layout.preferredWidth: 48 * root.s; Layout.preferredHeight: 28 * root.s
                        radius: height / 2
                        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        Text { anchors.centerIn: parent; text: I18n.tr("Ahora"); color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; font.weight: Font.Medium }
                        MotionArea { objectName: "weatherCurrent"; anchors.fill: parent; accessibleName: I18n.tr("Volver al clima actual"); onClicked: root.selectForecast(-1) }
                    }
                    Rectangle {
                        Layout.preferredWidth: 28 * root.s; Layout.preferredHeight: 28 * root.s
                        radius: height / 2
                        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        MaterialIcon {
                            anchors.centerIn: parent; iconName: "refresh"; color: Theme.iconSecondary; font.pixelSize: 17 * root.s
                            opacity: root.weatherLoading ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        }
                        ConfirmationIndicator { anchors.centerIn: parent; width: 20 * root.s; height: width; s: root.s; status: root.weatherLoading ? "busy" : "" }
                        MotionArea { objectName: "weatherRefresh"; anchors.fill: parent; enabled: !root.weatherLoading; accessibleName: I18n.tr("Actualizar clima"); onClicked: root.refreshWeatherRequested() }
                    }
                }
                // Lugar y frescura en una sola línea de metadatos.
                Text {
                    objectName: "weatherStatus"
                    Layout.fillWidth: true
                    Layout.topMargin: -6 * root.s
                    text: (root.weatherLocation || I18n.tr("Ubicación aproximada")) + " · "
                        + (root.weatherLoading ? I18n.tr("Actualizando…") : root.weatherError ? (root.weatherTemp ? I18n.tr("Sin actualizar · datos anteriores") : root.weatherError) : (root.weatherUpdated ? I18n.tr("Actualizado %1").arg(root.weatherUpdated) : "wttr.in"))
                    color: root.weatherError ? Theme.accent : Theme.iconSecondary
                    font.family: Theme.font; font.features: Theme.fontNumeric
                    font.pixelSize: Theme.fontSizeLabel * root.s; wrapMode: Text.WordWrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * root.s
                    opacity: root.weatherHeroOpacity
                    Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    AnimatedLabel {
                        Layout.fillWidth: true
                        objectName: "calendarForecastWeekday"
                        value: root.selectedForecast ? root.dayNames[new Date(root.selectedForecast.date + "T12:00:00").getDay()] : I18n.tr("Ahora mismo")
                        color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12 * root.s
                        Text {
                            objectName: "weatherTemperature"
                            Layout.fillWidth: true
                            text: root.selectedForecast ? root.selectedForecast.high : (root.weatherTemp || "—")
                            color: Theme.foreground; font.family: Theme.fontDisplay
                            font.pixelSize: 46 * root.s * Math.min(Flags.fontScale, 1.2); font.weight: Font.Medium
                            Accessible.role: Accessible.StaticText
                            Accessible.name: root.selectedForecast ? I18n.tr("Máxima %1 Celsius").arg(text) : I18n.tr("Temperatura %1 Celsius").arg(text)
                        }
                        MaterialIcon { iconName: root.selectedForecast ? root.selectedForecast.icon : root.weatherIcon; color: Theme.accent; font.pixelSize: 40 * root.s; opacity: root.weatherTemp ? 1 : 0.4 }
                    }
                    AnimatedLabel {
                        Layout.fillWidth: true
                        value: root.selectedForecast ? root.selectedForecast.label : (root.weatherDesc || (root.weatherLoading ? I18n.tr("Consultando clima…") : I18n.tr("Clima no disponible")))
                        color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; wrapMode: Text.WordWrap
                    }
                    AnimatedLabel {
                        Layout.fillWidth: true
                        value: root.selectedForecast ? I18n.tr("Máx. %1 · Mín. %2").arg(root.selectedForecast.high).arg(root.selectedForecast.low) : (root.weatherFeels ? I18n.tr("Sensación %1").arg(root.weatherFeels) : "")
                        visible: text.length > 0
                        color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; wrapMode: Text.WordWrap
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: Theme.borderHairline; color: Theme.border }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12 * root.s
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: I18n.tr("Humedad"); color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s }
                        Text { objectName: "weatherHumidityValue"; text: (root.selectedForecast ? root.selectedForecast.humidity : root.weatherHumidity) || "—"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: I18n.tr("Viento"); color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s }
                        Text { objectName: "weatherWindValue"; text: (root.selectedForecast ? root.selectedForecast.wind : root.weatherWind) || "—"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s }
                    }
                }
                Text { text: I18n.tr("Pronóstico"); visible: root.forecast.length > 0; color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; font.weight: Font.DemiBold }
                Repeater {
                    model: root.forecast
                    delegate: Rectangle {
                        id: forecastRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.s
                        radius: Theme.radiusSm * root.s
                        color: root.weatherView === index ? Qt.alpha(Theme.accent, Theme.alphaGlow) : "transparent"
                        Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6 * root.s
                            spacing: 8 * root.s
                            Text { Layout.preferredWidth: 30 * root.s; text: root.dayNames[new Date(forecastRow.modelData.date + "T12:00:00").getDay()].slice(0, 3); color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.Medium; elide: Text.ElideRight }
                            MaterialIcon { iconName: forecastRow.modelData.icon; color: Theme.accent; font.pixelSize: 18 * root.s }
                            Text { Layout.preferredWidth: 26 * root.s; horizontalAlignment: Text.AlignRight; text: forecastRow.modelData.low; color: Theme.iconSecondary; font.family: Theme.font; font.features: Theme.fontNumeric; font.pixelSize: Theme.fontSizeSmall * root.s }
                            // Barra de rango: el tramo mín–máx del día sobre la escala de toda la semana.
                            Rectangle {
                                id: rangeTrack
                                readonly property real lo: parseInt(forecastRow.modelData.low)
                                readonly property real hi: parseInt(forecastRow.modelData.high)
                                readonly property bool known: !!root.forecastRange && !isNaN(lo) && !isNaN(hi)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4 * root.s
                                radius: height / 2
                                color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                                Rectangle {
                                    visible: rangeTrack.known
                                    height: parent.height; radius: parent.radius
                                    x: rangeTrack.known ? (rangeTrack.lo - root.forecastRange.lo) / root.forecastRange.span * parent.width : 0
                                    width: rangeTrack.known ? Math.max(height, (rangeTrack.hi - rangeTrack.lo) / root.forecastRange.span * parent.width) : 0
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Qt.alpha(Theme.accent, Theme.alphaIconSec) }
                                        GradientStop { position: 1; color: Theme.accent }
                                    }
                                }
                            }
                            Text { Layout.preferredWidth: 26 * root.s; text: forecastRow.modelData.high; color: Theme.foreground; font.family: Theme.font; font.features: Theme.fontNumeric; font.pixelSize: Theme.fontSizeSmall * root.s; font.weight: Font.DemiBold }
                        }
                        MotionArea {
                            anchors.fill: parent; feedbackRadius: forecastRow.radius; hoverWash: false
                            accessibleName: I18n.tr("%1: %2, máxima %3, mínima %4").arg(forecastRow.modelData.date).arg(forecastRow.modelData.label).arg(forecastRow.modelData.high).arg(forecastRow.modelData.low)
                            onClicked: root.selectForecast(root.weatherView === forecastRow.index ? -1 : forecastRow.index)
                        }
                    }
                }

                }
            }

            Item {
                id: mediaFooter
                objectName: "calendarMediaFooter"
                visible: root.hasMedia
                Layout.fillWidth: true
                Layout.preferredHeight: visible
                    ? Math.max(44, (Theme.fontSizeBody + Theme.fontSizeCaption) * 1.4 + 8) * root.s : 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Theme.borderHairline
                    color: Qt.alpha(Theme.foreground, Theme.alphaHair)
                }
                IslandMediaSummary {
                    objectName: "calendarMediaSummary"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    s: root.s
                    coverDiameter: 36 * root.s
                    spacing: 12 * root.s
                    textWidth: Math.max(0, mediaFooter.width - 48 * root.s)
                    titlePixelSize: Theme.fontSizeBody * root.s
                    artistPixelSize: Theme.fontSizeCaption * root.s
                    artUrl: root.mediaArtUrl
                    title: root.mediaTitle
                    artist: root.mediaArtist
                    showArtist: root.mediaArtist.length > 0
                }
                MotionArea {
                    objectName: "calendarMediaOpen"
                    anchors.fill: parent
                    accessibleName: I18n.tr("Abrir música: %1 · %2").arg(root.mediaTitle).arg(root.mediaArtist)
                    onClicked: root.mediaRequested()
                }
            }
        }
    }
}
