import QtQuick
import "../components"

CalendarView {
    CalendarData { id: data }
    today: data.today
    weatherTemp: data.weatherTemp
    weatherDesc: data.weatherDesc
    weatherIcon: data.weatherIcon
    weatherLoading: data.weatherLoading
    weatherFeels: data.weatherFeels
    weatherHumidity: data.weatherHumidity
    weatherWind: data.weatherWind
    forecast: data.forecast
}
