import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Bar weather widget — shows temp + icon. Click opens forecast popup.
/// Replaces: waybar custom/weather module
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.weatherUnderline)
    Layout.fillHeight: true
    implicitWidth: weatherItem.implicitWidth

    BarUi.BarText {
        id: weatherItem
        bar: root.bar
        small: false
        style: root.instance.style ?? "underline"
        accent: root.accent
        clickable: true
        onClicked: forecastPopup.isOpen ? forecastPopup.close() : forecastPopup.open()
        text: {
            let set = root.instance.iconSet ?? "emoji";
            if (!Services.Weather.loaded) return Services.Icons.weatherPrefix(-1, set, root.accent) + "...";
            let unit = (root.instance.showUnit ?? true) ? Services.Weather.unitSymbol : "";
            let city = (root.instance.showCity ?? false) && Services.Weather.cityName !== ""
                ? Services.Icons.esc(Services.Weather.cityName) + " " : "";
            return Services.Icons.weatherPrefix(Services.Weather.weatherId, set, root.accent)
                + city
                + "<font color='" + Services.Weather.tempColor + "'>" + Services.Weather.temp + unit + "</font>";
        }
    }

    // Mod+Shift+W (IPC `weather`): toggle the forecast on the focused screen,
    // or on the primary one when the focused screen's layout has no weather.
    Connections {
        target: Services.Actions
        function onWeather() {
            let focused = Services.I3.focusedScreen;
            let mine = !focused || focused === root.bar?.screen;
            const profile = Services.Settings.barFor(focused?.name ?? "");
            const focusedLayout = profile.left.concat(profile.center, profile.right);
            let focusedHasWeather = focusedLayout.some(w => w.type === "weather");
            if (mine || (!focusedHasWeather && root.bar?.isPrimary))
                forecastPopup.isOpen ? forecastPopup.close() : forecastPopup.open();
        }
    }

    Components.WidgetPopup {
        id: forecastPopup
        bar: root.bar
        parentWidget: root
        contentWidth: 412
        accentColor: root.accent

        property string activeTab: "current"
        onOpening: activeTab = "current"

        Column {
            width: parent.width
            spacing: 10

            Components.PopupHeader {
                text: Services.Weather.loaded ? Services.Weather.cityName : "Weather"
                showClose: true
                showSeparator: false
                onCloseClicked: forecastPopup.close()
            }

            Components.SegmentedControl {
                width: parent.width
                model: [
                    { value: "current", label: "Now" },
                    { value: "forecast", label: "5-day forecast" }
                ]
                valueRole: "value"
                textRole: "label"
                currentValue: forecastPopup.activeTab
                onSelected: value => forecastPopup.activeTab = value
            }

            Components.StyledText {
                width: parent.width
                visible: !Services.Weather.loaded || Services.Weather.error
                wrapMode: Text.WordWrap
                color: Services.Colors.surfaceVariantText
                text: Services.Weather.errorMessage || "Loading weather…"
            }

            Rectangle {
                width: parent.width
                height: currentLayout.implicitHeight + 28
                visible: Services.Weather.loaded && forecastPopup.activeTab === "current"
                radius: Services.Ui.radiusLg
                color: Services.Ui.cardColor
                border.color: Services.Colors.outlineVariant
                border.width: 1

                Column {
                    id: currentLayout
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 14

                        Components.StyledText {
                            text: Services.Icons.markupWeather(Services.Weather.weatherId,
                                root.instance.iconSet ?? "auto", root.accent)
                            textFormat: Text.RichText
                            visible: text !== ""
                            font.pixelSize: Services.Ui.px(42)
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 3

                            Components.StyledText {
                                text: Services.Weather.temp + Services.Weather.unitSymbol
                                color: Services.Weather.tempColor
                                font.pixelSize: Services.Ui.px(34)
                                font.bold: true
                            }

                            Components.StyledText {
                                text: Services.Weather.description
                                font.pixelSize: Services.Ui.textBodyLarge
                            }
                        }
                    }

                    Components.StatRows {
                        width: parent.width
                        entries: [
                            ["Feels like", Services.Weather.feelsLike + Services.Weather.unitSymbol],
                            ["Humidity", Services.Weather.humidity + "%"],
                            ["Wind", Services.Weather.windSpeed + " " + Services.Weather.windUnit]
                        ]
                    }
                }
            }

            Flickable {
                id: daysView
                width: parent.width
                height: Math.min(390, daysColumn.implicitHeight)
                contentHeight: daysColumn.implicitHeight
                visible: Services.Weather.loaded && forecastPopup.activeTab === "forecast"
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: daysColumn
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: Services.Weather.forecast

                        delegate: Rectangle {
                            id: day
                            required property var modelData
                            function degrees(value) { return value === null ? "—" : value + "°"; }
                            width: daysColumn.width
                            height: dayRow.implicitHeight + 18
                            radius: Services.Ui.radiusMd
                            color: modelData.isToday ? Services.Colors.primaryContainer : Services.Ui.cardColor

                            RowLayout {
                                id: dayRow
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 10

                                Components.StyledText {
                                    text: Services.Icons.markupWeather(day.modelData.weatherId,
                                        root.instance.iconSet ?? "auto", root.accent)
                                    textFormat: Text.RichText
                                    visible: text !== ""
                                    font.pixelSize: Services.Ui.px(25)
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Components.StyledText {
                                        text: day.modelData.isToday ? "Today" : day.modelData.dayName
                                        font.pixelSize: Services.Ui.textBodyLarge
                                        font.bold: true
                                    }

                                    Components.StyledText {
                                        width: parent.width
                                        text: day.modelData.description + (day.modelData.pop === null
                                            ? "" : " · " + day.modelData.pop + "% precip.")
                                        elide: Text.ElideRight
                                        color: Services.Colors.surfaceVariantText
                                        font.pixelSize: Services.Ui.textSmall
                                    }
                                }

                                Column {
                                    spacing: 3

                                    Components.StyledText {
                                        anchors.right: parent.right
                                        text: day.degrees(day.modelData.tempMax) + " / " + day.degrees(day.modelData.tempMin)
                                        font.pixelSize: Services.Ui.textSubtitle
                                        font.bold: true
                                    }

                                    Components.StyledText {
                                        anchors.right: parent.right
                                        visible: day.modelData.windSpeed !== null
                                        text: day.modelData.windSpeed + " " + Services.Weather.windUnit
                                        color: Services.Colors.surfaceVariantText
                                        font.pixelSize: Services.Ui.textSmall
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Components.StyledText {
                width: parent.width
                text: 'Forecast by <a href="https://open-meteo.com/">Open-Meteo</a>'
                textFormat: Text.RichText
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textCaption
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }
}
