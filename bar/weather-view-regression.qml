import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true; width: 660; height: 470; color: Theme.background
        CalendarView {
            id: calendar
            open: true
            weatherTemp: "31°"; weatherDesc: "Parcialmente nublado con intervalos de lluvia"
            weatherHumidity: "42%"; weatherWind: "14 km/h"
            weatherLocation: "Una localidad de nombre muy largo para probar el espacio disponible"
            forecast: [{date:"2026-10-08",high:"31°",low:"24°",icon:"rainy",label:"Lluvia",humidity:"87%",wind:"20 km/h"}]
        }
        SignalSpy { id: refresh; target: calendar; signalName: "refreshWeatherRequested" }
        TestCase {
            when: scene.visible
            function test_weather() {
                Config.update({appearance:{fontScale:1.2,reduceMotion:false}})
                wait(100)
                const weather = findChild(calendar, "calendarWeather")
                const temperature = findChild(calendar, "weatherTemperature")
                verify(weather.width >= 180 && weather.x + weather.width <= calendar.width)
                verify(temperature.width > 0 && temperature.width <= weather.width)
                const button = findChild(calendar,"weatherRefresh")
                mouseClick(button,button.width/2,button.height/2,Qt.LeftButton)
                compare(refresh.count,1)
                calendar.weatherLoading = true
                verify(!button.enabled)
                verify(findChild(calendar,"weatherStatus").text.includes("Actualizando"))
                calendar.weatherLoading = false
                calendar.selectForecast(0)
                wait(400)
                compare(findChild(calendar,"weatherHumidityValue").text,"87%")
                compare(findChild(calendar,"weatherWindValue").text,"20 km/h")
                const current = findChild(calendar,"weatherCurrent")
                mouseClick(current,current.width/2,current.height/2,Qt.LeftButton)
                wait(400)
                compare(calendar.weatherView,-1)
                compare(findChild(calendar,"weatherHumidityValue").text,"42%")
                calendar.weatherError = "No se pudo actualizar el clima"
                const status = findChild(calendar,"weatherStatus")
                verify(status.text.includes("datos anteriores"))
                const statusPoint = status.mapToItem(weather,0,0)
                verify(statusPoint.y >= 0 && statusPoint.y + status.height <= weather.height, "stale notice is visible without scrolling")
                Config.update({appearance:{fontScale:1.75,reduceMotion:true}})
                wait(100)
                verify(weather.contentHeight >= 0 && temperature.width <= weather.width)
                calendar.selectForecast(0)
                compare(calendar.weatherView,0)
                calendar.forecast = []
                compare(calendar.weatherView,-1)
                calendar.weatherTemp = ""
                verify(findChild(calendar,"weatherStatus").text.includes("No se pudo"))
                console.log("PASS: weather layout, refresh, loading, forecast metrics, now, stale/empty, large font and reduced motion")
            }
        }
    }
}
