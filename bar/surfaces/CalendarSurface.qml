import QtQuick
import "../components"
import "../Singletons"

CalendarView {
    signal requestPage(string name)
    onMediaRequested: requestPage("media")
    CalendarData { id: data }
    hasMedia: Players.has
    mediaTitle: Players.title
    mediaArtist: Players.artist
    mediaArtUrl: Players.artUrl
    today: data.today
    weatherTemp: data.weatherTemp
    weatherDesc: data.weatherDesc
    weatherIcon: data.weatherIcon
    weatherLoading: data.weatherLoading
    weatherFeels: data.weatherFeels
    weatherHumidity: data.weatherHumidity
    weatherWind: data.weatherWind
    weatherError: data.weatherError
    weatherLocation: data.weatherLocation
    weatherUpdated: data.weatherUpdated
    onRefreshWeatherRequested: data.refresh()
    forecast: data.forecast
}
