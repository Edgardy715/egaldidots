import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.today = new Date() }

    // ---- Weather (wttr.in, robusto: fallback offline + iconos Material) ----
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherIcon: "cloud"
    property bool weatherLoading: false

    function mapWeather(code: int, isNight: bool): string {
        if (code >= 200 && code < 300) return "thunderstorm"
        if (code >= 300 && code < 400) return "rainy_light"
        if (code >= 500 && code < 600) return "water_drop"
        if (code >= 600 && code < 700) return "ac_unit"
        if (code >= 700 && code < 800) return "foggy"
        if (code === 800) return isNight ? "dark_mode" : "sunny"
        if (code > 800 && code < 803) return isNight ? "partly_cloudy_night" : "partly_cloudy_day"
        if (code === 803 || code === 804) return "cloud"
        return "thermostat"
    }

    Component.onCompleted: {
        weatherLoading = true
        getWeather.running = true
        weatherTimer.running = true
    }
    Timer {
        id: weatherTimer
        interval: 15 * 60 * 1000
        repeat: true
        onTriggered: {
            getWeather.running = true
            weatherLoading = true
        }
    }
    Process {
        id: getWeather
        running: false
        command: ["bash", "-c", "curl -sf --connect-timeout 3 --max-time 5 'wttr.in/?format=j1' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            id: weatherCol
            onStreamFinished: {
                root.weatherLoading = false
                try {
                    var d = JSON.parse(weatherCol.text || "{}")
                    var cc = d.current_condition && d.current_condition[0]
                    if (cc && cc.temp_C !== undefined) {
                        root.weatherTemp = cc.temp_C + "°"
                        root.weatherDesc = (cc.weatherDesc && cc.weatherDesc[0] && cc.weatherDesc[0].value) || ""
                        var code = parseInt(cc.weatherCode) || 0
                        var h = (new Date()).getHours()
                        root.weatherIcon = root.mapWeather(code, h < 6 || h >= 20)
                    }
                } catch (e) { }
            }
        }
    }

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
    readonly property real cellGap: 5 * s
    readonly property real cellSize: {
        var wAvail = (gridHost.width - 6 * root.cellGap) / 7
        var hAvail = (gridHost.height - (root.gridRows - 1) * root.cellGap) / root.gridRows
        return Math.max(10, Math.min(wAvail, hAvail))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXl * s

        // ═══════════ HEADER: fecha grande + reloj + clima ═══════════
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s

            // fecha del día (display grande)
            ColumnLayout {
                spacing: Theme.spacingXxs * s
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: root.locale.dayName(root.today.getDay()).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8
                    textFormat: Text.PlainText
                }
                Text {
                    text: root.today.getDate()
                    color: Theme.foreground
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeHeroLg * s
                    font.weight: Font.DemiBold
                    lineHeight: 0.95
                }
            }

            Item { Layout.fillWidth: true }

            // bloque derecho: reloj + clima
            ColumnLayout {
                spacing: Theme.spacingSm * s
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 0
                Layout.maximumWidth: 132 * s

                // reloj vivo
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(root.today, Flags.time12h ? "h:mm" : "HH:mm")
                    color: Theme.foreground
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeTitle * s
                    font.weight: Font.DemiBold
                }

                // clima: icono + temp
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.spacingMd * s

                    Rectangle {
                        Layout.preferredWidth: 28 * s
                        Layout.preferredHeight: 28 * s
                        radius: 9 * s
                        color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                        border.width: Theme.borderHairline
                        border.color: Qt.alpha(Theme.accent, Theme.alphaSoft)

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: root.weatherIcon
                            color: Theme.accent
                            font.pixelSize: Theme.fontSizeBodyLg * s
                        }
                    }
                    Text {
                        text: root.weatherTemp || (root.weatherLoading ? "—" : "")
                        color: Theme.foreground
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSizeBodyLg * s
                        font.weight: Font.Medium
                    }
                }

                // desc del clima (elide)
                Text {
                    Layout.alignment: Qt.AlignRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: 132 * s
                    text: root.weatherDesc
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * s
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    visible: root.weatherDesc.length > 0
                }
            }
        }

        // ═══════════ NAV de mes ═══════════
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * s

            // prev
            Rectangle {
                id: prevBtn
                Layout.preferredWidth: 28 * s; Layout.preferredHeight: 28 * s
                radius: height / 2
                color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: prevMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                scale: prevMa.containsMouse ? 1.05 : 1.0
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on scale { Anim { type: Anim.FastEffects } }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: Icons.iChevronLeft
                    color: prevMa.containsMouse ? Theme.accent : Theme.foreground
                    font.pixelSize: Theme.fontSizeTitleLg * s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(-1) }
            }

            Item { Layout.fillWidth: true }

            // mes + año (crossfade al cambiar)
            Text {
                text: root.locale.monthName(root.viewMonth).charAt(0).toUpperCase()
                      + root.locale.monthName(root.viewMonth).slice(1) + " " + root.viewYear
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * s
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            // next
            Rectangle {
                id: nextBtn
                Layout.preferredWidth: 28 * s; Layout.preferredHeight: 28 * s
                radius: height / 2
                color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: nextMa.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                scale: nextMa.containsMouse ? 1.05 : 1.0
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on scale { Anim { type: Anim.FastEffects } }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: Icons.iChevronRight
                    color: nextMa.containsMouse ? Theme.accent : Theme.foreground
                    font.pixelSize: Theme.fontSizeTitleLg * s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(1) }
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
                    Layout.preferredWidth: root.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: (index === 0 || index === 6) ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * s
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
                        readonly property int dayNum: index - root.offset + 1
                        readonly property bool inMonth: index >= root.offset && dayNum <= root.length
                        readonly property bool isToday: inMonth
                            && dayNum === root.today.getDate()
                            && root.viewMonth === root.today.getMonth()
                            && root.viewYear === root.today.getFullYear()
                        readonly property bool selected: inMonth && dayNum === root.selectedDay
                        readonly property bool weekend: (index % 7) === 0 || (index % 7) === 6

                        entered: root.open
                        staggerIndex: Math.floor(index / 7)
                        s: root.s
                        restartKey: root.monthEpoch
                        scaleFrom: 0.88

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
                                if (isToday) return Theme.accent
                                if (selected) return Qt.alpha(Theme.accent, Theme.alphaGlow)
                                if (cellMa.containsMouse && inMonth) return Qt.alpha(Theme.accent, Theme.alphaSoft)
                                return weekend && inMonth ? Qt.alpha(Theme.foreground, Theme.alphaGhost) : "transparent"
                            }
                            border.color: {
                                if (isToday) return Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                                if (selected) return Qt.alpha(Theme.accent, Theme.alphaDisabled)
                                if (cellMa.containsMouse && inMonth) return Qt.alpha(Theme.accent, Theme.alphaSelected)
                                return "transparent"
                            }
                            border.width: Theme.borderHairline
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                            // glow suave detrás del "hoy"
                            Rectangle {
                                visible: isToday
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: Theme.borderEmphasis * s
                                border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                                BreatheBorder {
                                    glowColor: Theme.accent
                                    width_: 2 * s
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
                                anchors.centerIn: parent
                                text: inMonth ? dayNum : ""
                                color: isToday ? Theme.background
                                              : selected ? Theme.accent
                                                         : (cellMa.containsMouse && inMonth ? Theme.foreground
                                                                                             : (weekend && inMonth ? Qt.alpha(Theme.foreground, Theme.alphaIconSec) : Theme.foreground))
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeBodyLg * s
                                font.weight: isToday ? Font.DemiBold : (selected ? Font.DemiBold : Font.Medium)
                                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            }

                            // punto indicador sutil bajo el día actual
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4 * s
                                width: 3 * s
                                height: 3 * s
                                radius: width / 2
                                color: Theme.accent
                                opacity: isToday ? 1 : 0
                            }
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (inMonth) root.selectedDay = dayNum
                        }
                    }
                }
            }
        }
    }
}
