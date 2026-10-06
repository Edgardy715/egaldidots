import QtQuick
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    CalendarData { id: weather; observe: false }
    Item {
        width: 825; height: 588
        CalendarView {
            id: calendar
            open: true; s: 1.25
            today: new Date(2024, 1, 29, 12, 0, 0)
            forecast: weather.forecast
            weatherTemp: weather.weatherTemp
        }
    }
    function check(value, message) {
        if (!value) { console.error("FAIL: " + message); Qt.callLater(() => Qt.exit(1)) }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            check(calendar.length === 29 && calendar.offset === 4 && calendar.cellCount === 35, "leap month grid")
            calendar.viewMonth = 11
            calendar.viewYear = 2024
            calendar.shiftMonth(1)
            check(calendar.viewMonth === 0 && calendar.viewYear === 2025, "year boundary")
            check(calendar.cellSize > 0, "scaled grid fits")
            check(weather.mapWeather(113, true) === "dark_mode" && weather.mapWeather(296, false) === "rainy", "WWO mapping")
            const fixture = {current_condition:[{temp_C:"27", weatherCode:"113", FeelsLikeC:"29", humidity:"60", windspeedKmph:"10"}],
                weather:[{date:"2024-02-29", maxtempC:"28", mintempC:"20", hourly:[{weatherCode:"296"}]},
                    {date:"2024-03-01", maxtempC:"29", mintempC:"21", hourly:[{weatherCode:"116"}]}]}
            weather.parseWeather(JSON.stringify(fixture))
            check(weather.weatherTemp === "27°" && weather.weatherHumidity === "60%", "current weather")
            check(calendar.forecast.length === 2 && calendar.forecast[0].icon === "rainy", "forecast projection")
            weather.weatherLoading = true
            weather.parseWeather("invalid json")
            check(!weather.weatherLoading && weather.weatherTemp === "27°", "parse failure retains last data")
            calendar.selectForecast(1)
            finish.start()
        }
    }
    Timer {
        id: finish; interval: 350
        onTriggered: {
            check(calendar.weatherView === 1 && calendar.weatherHeroOpacity === 1, "forecast swap")
            calendar.closing = true
            check(calendar.weatherHeroOpacity === 1, "close settles forecast")
            console.log("PASS: calendar leap/year/scaled grid and injected weather parsing/forecast/error/closing without network")
            Qt.quit()
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: calendar timeout"); Qt.exit(1) } }
}
