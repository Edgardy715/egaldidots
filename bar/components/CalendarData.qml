import QtQuick
import Quickshell.Io

// Clock and weather observation; no presentation or date-selection state.
Item {
    id: root
    property bool observe: true
    property date today: new Date()
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherIcon: "cloud"
    property bool weatherLoading: false
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherWind: ""
    property var forecast: []
    function mapWeather(code: int, isNight: bool): string {
        // wttr.in entrega códigos WWO, no los códigos OpenWeather 2xx/8xx.
        if ([200, 386, 389, 392, 395].includes(code)) return "thunderstorm"
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(code)) return "ac_unit"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(code)) return "rainy"
        if ([143, 248, 260].includes(code)) return "foggy"
        if (code === 113) return isNight ? "dark_mode" : "sunny"
        if (code === 116) return isNight ? "partly_cloudy_night" : "partly_cloudy_day"
        return "cloud"
    }

    function weatherLabel(code: int): string {
        if (code === 113) return qsTr("Despejado")
        if (code === 116) return qsTr("Parcialmente nublado")
        if ([119, 122].includes(code)) return qsTr("Nublado")
        if ([143, 248, 260].includes(code)) return qsTr("Niebla")
        if (mapWeather(code, false) === "thunderstorm") return qsTr("Tormenta")
        if (mapWeather(code, false) === "ac_unit") return qsTr("Nieve")
        return qsTr("Lluvia")
    }

    function parseWeather(output) {
        root.weatherLoading = false
        try {
            var d = JSON.parse(output || "{}")
            var cc = d.current_condition && d.current_condition[0]
            if (cc && cc.temp_C !== undefined) {
                root.weatherTemp = cc.temp_C + "°"
                var code = parseInt(cc.weatherCode) || 0
                var h = (new Date()).getHours()
                root.weatherIcon = root.mapWeather(code, h < 6 || h >= 20)
                root.weatherDesc = root.weatherLabel(code)
                root.weatherFeels = cc.FeelsLikeC + "°"
                root.weatherHumidity = cc.humidity + "%"
                root.weatherWind = cc.windspeedKmph + " km/h"
                root.forecast = (d.weather || []).slice(0, 3).map(day => ({
                    date: day.date,
                    high: day.maxtempC + "°",
                    low: day.mintempC + "°",
                    icon: root.mapWeather(parseInt((day.hourly || [])[4]?.weatherCode || (day.hourly || [])[0]?.weatherCode || "0") || 0, false),
                    label: root.weatherLabel(parseInt((day.hourly || [])[4]?.weatherCode || (day.hourly || [])[0]?.weatherCode || "0") || 0)
                }))
            }
        } catch (e) { }
    }
    function refresh() { weatherLoading = true; getWeather.running = true }
    Component.onCompleted: if (observe) refresh()
    Timer { interval: 1000; repeat: true; running: root.observe; onTriggered: root.today = new Date() }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.observe; onTriggered: root.refresh() }
    Process {
        id: getWeather
        command: ["curl", "-fsS", "--connect-timeout", "3", "--max-time", "8", "https://wttr.in/?format=j1"]
        stdout: StdioCollector { onStreamFinished: root.parseWeather(text) }
    }
}
