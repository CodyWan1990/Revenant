import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    // ─── Now ───
    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Now"
        description: Services.Weather.error ? Services.Weather.errorMessage
            : !Services.Weather.loaded ? "Loading…" : ""

        RowLayout {
            width: parent.width
            visible: Services.Weather.loaded && !Services.Weather.error
            spacing: 18

            // Condition icon, in the global icon set.
            Components.StyledText {
                textFormat: Text.RichText
                text: Services.Icons.span(Services.Icons.weather(Services.Weather.weatherId, "auto"),
                    "auto", Services.Colors.accent)
                font.pixelSize: Services.Ui.px(44)
            }

            Column {
                spacing: 2
                Components.StyledText {
                    text: Services.Weather.temp + Services.Weather.unitSymbol
                    color: Services.Weather.tempColor
                    font.pixelSize: Services.Ui.px(32)
                    font.bold: true
                }
                Components.StyledText {
                    text: Services.Weather.description.charAt(0).toUpperCase()
                        + Services.Weather.description.slice(1) + " · " + Services.Weather.cityName
                    color: Services.Colors.foreground
                    font.pixelSize: Services.Ui.textBodyLarge
                }
            }

            Item { Layout.fillWidth: true }

            Components.StatRows {
                Layout.preferredWidth: 220
                entries: [
                    ["Feels like", Services.Weather.feelsLike + Services.Weather.unitSymbol],
                    ["Humidity", Services.Weather.humidity + "%"],
                    ["Wind", Services.Weather.windSpeed + " " + Services.Weather.windUnit]
                ]
            }
        }

        Components.TextButton {
            text: "↻  Refresh now"
            onClicked: Services.Weather.refresh()
        }
    }

    // ─── Location ───
    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Your location"
        description: "Used for the weather widget on the bar. Press Enter when you are done typing."

        SettingsUi.OptionRow {
            title: "City"
            Components.SettingField {
                width: parent.width
                placeholder: "e.g. London"
                Component.onCompleted: text = Services.Settings.weatherCity
                onEdited: v => Services.Settings.weatherCity = v.trim()
            }
        }

        SettingsUi.OptionRow {
            title: "Country"
            description: "Optional. Helps when several places share a name (London, UK or London, Canada)."
            Components.SettingField {
                width: parent.width
                placeholder: "e.g. UK or GB"
                Component.onCompleted: text = Services.Settings.weatherCountry
                onEdited: v => Services.Settings.weatherCountry = v.trim()
            }
        }

        SettingsUi.ChoiceRow {
            title: "Units"
            choices: [{ value: "metric", label: "Celsius (°C)", hint: "Wind in metres per second." },
                      { value: "imperial", label: "Fahrenheit (°F)", hint: "Wind in miles per hour." }]
            value: Services.Settings.weatherUnits
            onSelected: value => Services.Settings.weatherUnits = value
        }
    }

    Components.StyledText {
        x: root.horizontalPadding
        width: root.rowWidth
        text: 'Forecast by <a href="https://open-meteo.com/">Open-Meteo</a>'
        textFormat: Text.RichText
        color: Services.Colors.surfaceVariantText
        onLinkActivated: link => Qt.openUrlExternally(link)
    }
}
