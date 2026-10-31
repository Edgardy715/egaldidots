import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 660; height: 470
        color: Theme.background
        CalendarView {
            id: calendar
            open: true
            today: new Date(2026, 9, 26, 12)
            forecast: [{date: "2026-10-28", high: "31°", low: "24°", icon: "rainy", label: "Lluvia"}]
        }
        TestCase {
            when: scene.visible
            function test_design() {
                Config.update({appearance: {reduceMotion: true}})
                wait(100)
                const days = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
                const months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
                const heading = findChild(calendar, "calendarTodayWeekday")
                const title = findChild(calendar, "calendarMonthTitle")
                for (let day = 0; day < 7; day++) {
                    compare(calendar.dayNames[day], days[day])
                    calendar.today = new Date(2026, 9, 25 + day, 12)
                    compare(heading.text, days[day].toUpperCase())
                }
                for (let month = 0; month < 12; month++) {
                    compare(calendar.monthNames[month], months[month])
                    calendar.viewMonth = month
                    compare(title.value, months[month][0].toUpperCase() + months[month].slice(1) + " 2026")
                }
                calendar.selectForecast(0)
                compare(findChild(calendar, "calendarForecastWeekday").text, "miércoles")

                const previous = findChild(calendar, "calendarPreviousMonth")
                const next = findChild(calendar, "calendarNextMonth")
                compare(previous.accessibleName, "Mes anterior")
                compare(next.accessibleName, "Mes siguiente")
                verify(previous.activeFocusOnTab && next.activeFocusOnTab)
                for (const scale of [0.8, 1, 1.25]) {
                    calendar.s = scale
                    scene.width = 660 * scale
                    scene.height = 470 * scale
                    wait(50)
                    verify(previous.width >= 32 && previous.height >= 32)
                    verify(next.width >= 32 && next.height >= 32)
                    const left = previous.mapToItem(calendar, 0, 0)
                    const right = next.mapToItem(calendar, 0, 0)
                    verify(left.x + previous.width <= right.x, "navigation targets do not overlap")
                    verify(left.x >= 0 && right.x + next.width <= calendar.width)
                    for (let month = 0; month < 12; month++) {
                        calendar.viewMonth = month
                        wait(1)
                        verify(title.width >= findChild(title, "crossfadeText").implicitWidth, "month remains legible")
                    }
                    calendar.viewMonth = 11
                    calendar.viewYear = 2026
                    mouseClick(next, 2, 2, Qt.LeftButton)
                    compare(calendar.viewMonth, 0)
                    compare(calendar.viewYear, 2027)
                    mouseClick(previous, 2, 2, Qt.LeftButton)
                    compare(calendar.viewMonth, 11)
                    compare(calendar.viewYear, 2026)
                }
                scene.requestActivate()
                previous.forceActiveFocus()
                tryCompare(previous, "activeFocus", true)
                keyClick(Qt.Key_Return)
                compare(calendar.viewMonth, 10)
                next.forceActiveFocus()
                keyClick(Qt.Key_Space)
                compare(calendar.viewMonth, 11)
                console.log("PASS: calendar Spanish days/months/forecast, scaled targets, mouse year boundaries and keyboard navigation")
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 5000; running: true
        onTriggered: { console.error("FAIL: calendar design timeout"); Qt.exit(1) }
    }
}
