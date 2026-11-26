pragma Singleton

import QtQuick
import "." as Services

/// Open-Meteo geocoding and five-day forecast.
QtObject {
    readonly property string cityName: internal.cityName
    readonly property int temp: internal.temp
    readonly property int feelsLike: internal.feelsLike
    readonly property string description: internal.description
    readonly property int humidity: internal.humidity
    readonly property string windSpeed: internal.windSpeed
    readonly property int weatherId: internal.weatherId
    readonly property color tempColor: getTempColor(temp)
    readonly property bool imperial: Services.Settings.weatherUnits === "imperial"
    readonly property string unitSymbol: imperial ? "°F" : "°C"
    readonly property string windUnit: imperial ? "mph" : "m/s"
    readonly property var forecast: internal.forecast
    readonly property bool loaded: internal.loaded
    readonly property string errorMessage: internal.errorMessage
    readonly property bool error: errorMessage !== ""

    function refresh() { internal.requestFetch(); }

    function getTempColor(value) {
        const celsius = imperial ? (value - 32) * 5 / 9 : value;
        return celsius < 0 ? Services.Colors.color4
            : celsius >= 35 ? Services.Colors.red
            : celsius >= 25 ? Services.Colors.orange : Services.Colors.foreground;
    }

    readonly property QtObject internal: QtObject {
        id: internal

        property string cityName: ""
        property int temp: 0
        property int feelsLike: 0
        property string description: ""
        property int humidity: 0
        property string windSpeed: "0.0"
        property int weatherId: -1
        property var forecast: []
        property bool loaded: false
        property string errorMessage: ""
        property int requestVersion: 0
        property string locationKey: ""
        property var location: null

        // Map WMO codes into the existing icon categories.
        readonly property var conditions: ({
            0: [800, "Clear"], 1: [801, "Mostly clear"], 2: [802, "Partly cloudy"],
            3: [804, "Overcast"], 45: [741, "Fog"], 48: [741, "Freezing fog"],
            51: [300, "Light drizzle"], 53: [300, "Drizzle"], 55: [300, "Heavy drizzle"],
            56: [300, "Light freezing drizzle"], 57: [300, "Freezing drizzle"],
            61: [500, "Light rain"], 63: [500, "Rain"], 65: [500, "Heavy rain"],
            66: [500, "Light freezing rain"], 67: [500, "Freezing rain"],
            71: [600, "Light snow"], 73: [600, "Snow"], 75: [600, "Heavy snow"],
            77: [600, "Snow grains"], 80: [500, "Light showers"], 81: [500, "Rain showers"],
            82: [500, "Heavy showers"], 85: [600, "Snow showers"], 86: [600, "Heavy snow showers"],
            95: [200, "Thunderstorms"], 96: [200, "Thunderstorms with hail"],
            99: [200, "Thunderstorms with heavy hail"]
        })

        property Timer debounce: Timer { interval: 250; onTriggered: internal.fetch() }
        property Timer pollTimer: Timer {
            interval: 900000
            running: true
            repeat: true
            onTriggered: internal.requestFetch()
        }
        property Connections settingsConn: Connections {
            target: Services.Settings
            function onWeatherCityChanged() { internal.requestFetch(true); }
            function onWeatherCountryChanged() { internal.requestFetch(true); }
            function onWeatherUnitsChanged() { internal.requestFetch(true); }
        }

        function requestFetch(reset = false) {
            requestVersion++;
            if (reset) {
                loaded = false;
                forecast = [];
            }
            errorMessage = "";
            debounce.restart();
        }

        function request(url, version, onResult, failure) {
            const xhr = new XMLHttpRequest();
            xhr.timeout = 15000;
            xhr.ontimeout = function () {
                if (version === internal.requestVersion)
                    internal.errorMessage = failure;
            };
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE || version !== internal.requestVersion)
                    return;
                if (xhr.status !== 200) {
                    internal.errorMessage = failure;
                    return;
                }
                try {
                    onResult(JSON.parse(xhr.responseText));
                } catch (error) {
                    internal.errorMessage = failure;
                    console.warn("Weather:", error);
                }
            };
            xhr.open("GET", url);
            xhr.send();
        }

        function fetch() {
            const city = Services.Settings.weatherCity.trim();
            const country = Services.Settings.weatherCountry.trim();
            if (city.length < 2) {
                errorMessage = "Set a city in Weather settings.";
                return;
            }
            const version = requestVersion;
            const key = city + "|" + country;
            if (location && locationKey === key) {
                fetchForecast(location, version);
                return;
            }
            const isCode = /^[a-z]{2}$/i.test(country);
            const name = country && !isCode ? city + ", " + country : city;
            const url = "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name)
                + (isCode ? "&countryCode=" + country.toUpperCase() : "");
            request(url, version, data => {
                const match = data.results?.[0];
                if (!match) {
                    internal.errorMessage = "No location matched. Check the city and country.";
                    return;
                }
                internal.locationKey = key;
                internal.location = match;
                internal.fetchForecast(match, version);
            }, "Could not look up the weather location.");
        }

        function fetchForecast(place, version) {
            const imperial = Services.Settings.weatherUnits === "imperial";
            const url = "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude
                + "&longitude=" + place.longitude + "&timezone=auto&forecast_days=5"
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code"
                + "&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,wind_speed_10m_max"
                + (imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "&wind_speed_unit=ms");
            request(url, version, data => internal.applyForecast(place, data), "Could not refresh the forecast.");
        }

        function applyForecast(place, data) {
            const current = data.current;
            const daily = data.daily;
            if (!Number.isFinite(current?.temperature_2m) || !daily?.time?.length)
                throw new Error("Open-Meteo response has no forecast");
            const condition = conditions[current.weather_code] ?? [-1, "Unknown conditions"];
            const days = daily.time.slice(0, 5).map((day, index) => {
                const parts = day.split("-").map(Number);
                const date = new Date(parts[0], parts[1] - 1, parts[2]);
                const info = conditions[daily.weather_code?.[index]] ?? [-1, "Unknown conditions"];
                const low = daily.temperature_2m_min?.[index];
                const high = daily.temperature_2m_max?.[index];
                return {
                    dayName: date.toLocaleDateString(Qt.locale(), "ddd, MMM d"),
                    tempMin: Number.isFinite(low) ? Math.round(low) : null,
                    tempMax: Number.isFinite(high) ? Math.round(high) : null,
                    description: info[1],
                    weatherId: info[0],
                    windSpeed: daily.wind_speed_10m_max?.[index] ?? null,
                    pop: daily.precipitation_probability_max?.[index] ?? null,
                    isToday: index === 0
                };
            });
            cityName = place.name;
            temp = Math.round(current.temperature_2m);
            feelsLike = Math.round(current.apparent_temperature);
            humidity = current.relative_humidity_2m;
            windSpeed = current.wind_speed_10m.toFixed(1);
            weatherId = condition[0];
            description = condition[1];
            forecast = days;
            loaded = true;
            errorMessage = "";
            console.log("Weather: Open-Meteo forecast loaded,", days.length, "days");
        }

        Component.onCompleted: requestFetch()
    }
}
