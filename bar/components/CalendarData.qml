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
    property string weatherError: ""
    property string weatherLocation: ""
    property string weatherUpdated: ""
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
        if (mapWeather(code, false) === "rainy") return qsTr("Lluvia")
        return qsTr("Sin descripción")
    }

    function measurement(value, suffix, minimum, maximum) {
        if (value === undefined || value === null || String(value).trim() === "") return ""
        const n = Number(value)
        return Number.isFinite(n) && n >= minimum && n <= maximum ? String(n) + suffix : ""
    }
    function parseWeather(output) {
        root.weatherLoading = false
        try {
            const d = JSON.parse(output || "{}")
            const cc = d.current_condition && d.current_condition[0]
            const temp = cc ? measurement(cc.temp_C, "°", -100, 100) : ""
            if (!temp) throw new Error("Missing temperature")
            const days = (Array.isArray(d.weather) ? d.weather : []).slice(0, 3).map(day => {
                const hours = Array.isArray(day.hourly) ? day.hourly : []
                const noon = hours[4] || hours[0] || {}
                const code = Number(noon.weatherCode) || 0
                return {date: day.date, high: measurement(day.maxtempC, "°", -100, 100),
                    low: measurement(day.mintempC, "°", -100, 100), icon: mapWeather(code, false),
                    label: weatherLabel(code), humidity: measurement(noon.humidity, "%", 0, 100),
                    wind: measurement(noon.windspeedKmph, " km/h", 0, 500)}
            }).filter(day => typeof day.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(day.date)
                && !isNaN(Date.parse(day.date)) && day.high && day.low)
            root.weatherTemp = temp
            const code = Number(cc.weatherCode) || 0
            const h = root.today.getHours()
            root.weatherIcon = mapWeather(code, h < 6 || h >= 20)
            root.weatherDesc = weatherLabel(code)
            root.weatherFeels = measurement(cc.FeelsLikeC, "°", -100, 100)
            root.weatherHumidity = measurement(cc.humidity, "%", 0, 100)
            root.weatherWind = measurement(cc.windspeedKmph, " km/h", 0, 500)
            const area = d.nearest_area && d.nearest_area[0]
            root.weatherLocation = String(area?.areaName?.[0]?.value || "").slice(0, 80)
            root.forecast = days
            root.weatherUpdated = Qt.formatDateTime(new Date(), "HH:mm")
            root.weatherError = ""
        } catch (e) { root.weatherError = qsTr("No se pudo actualizar el clima") }
    }
    function refresh() {
        if (getWeather.running) return
        weatherLoading = true
        weatherError = ""
        getWeather.running = true
    }
    Component.onCompleted: if (observe) refresh()
    Timer { interval: 1000; repeat: true; running: root.observe; onTriggered: root.today = new Date() }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.observe; onTriggered: root.refresh() }
    Process {
        id: getWeather
        command: ["curl", "-fsS", "--connect-timeout", "3", "--max-time", "8", "https://wttr.in/?format=j1"]
        stdout: StdioCollector { onStreamFinished: root.parseWeather(text) }
    }
}
