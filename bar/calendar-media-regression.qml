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
        width: 660
        height: 470
        color: Theme.background

        Rectangle {
        id: stage
        width: 660
        height: 470
        color: Theme.background
        CalendarView {
            id: calendar
            open: true
            weatherTemp: "27°"
            weatherDesc: "Despejado"
            forecast: [
                {date:"2026-10-11", high:"28°", low:"21°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-12", high:"29°", low:"22°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-13", high:"30°", low:"23°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-14", high:"31°", low:"24°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-15", high:"32°", low:"25°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-16", high:"33°", low:"26°", icon:"sunny", label:"Despejado"},
                {date:"2026-10-17", high:"34°", low:"27°", icon:"sunny", label:"Despejado"}
            ]
        }
        SignalSpy { id: mediaSpy; target: calendar; signalName: "mediaRequested" }
        TestCase {
            when: scene.visible
            function test_calendarMedia() {
                const footer = findChild(calendar, "calendarMediaFooter")
                const summary = findChild(calendar, "calendarMediaSummary")
                const open = findChild(calendar, "calendarMediaOpen")
                const weather = findChild(calendar, "calendarWeather")
                verify(footer && summary && open && weather)
                verify(!footer.visible)

                for (const layout of ["split", "compact"]) {
                    Config.update({appearance:{barLayout:layout, fontScale:1, reduceMotion:false}})
                    calendar.hasMedia = true
                    calendar.mediaTitle = "Un título de canción largo que debe truncarse en la columna estrecha del calendario"
                    calendar.mediaArtist = "Artista de prueba"
                    wait(100)
                    verify(footer.visible && summary.width <= footer.width + 1)
                    verify(weather.height > 280)
                    const footerTop = footer.mapToItem(calendar, 0, 0).y
                    verify(footerTop >= 0 && footerTop + footer.height <= calendar.height + 1)
                    verify(weather.contentHeight > weather.height)
                    weather.contentY = weather.contentHeight - weather.height
                    wait(50)
                    compare(footer.mapToItem(calendar, 0, 0).y, footerTop)
                    const captureDir = Quickshell.env("ISLA_CALENDAR_MEDIA_CAPTURE_DIR")
                    if (captureDir) {
                        wait(1400)
                        let saved = false
                        stage.grabToImage(image => {
                            saved = image.saveToFile(captureDir + "/calendar-media-" + layout + ".png")
                        })
                        tryVerify(() => saved, 2000)
                    }
                    mouseClick(open, open.width / 2, open.height / 2, Qt.LeftButton)
                    compare(mediaSpy.count, layout === "split" ? 1 : 2)
                    calendar.mediaTitle = "Pausada"
                    verify(footer.visible && summary.title === "Pausada")
                }

                Config.update({appearance:{fontScale:1.75, reduceMotion:true}})
                wait(100)
                verify(footer.height >= summary.height)
                verify(weather.height > 240)
                calendar.hasMedia = false
                wait(30)
                verify(!footer.visible)
                verify(weather.height > 280)
                console.log("PASS: calendar media footer in split/compact, paused/removal, long title, scroll, click, large text and reduced motion")
            }
        }
        }
    }
}
