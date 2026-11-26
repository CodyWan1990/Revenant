import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Bar ▸ Appearance: where the bar sits and how big it is, then the widget
/// style (polybar or Dux Shell's pills / segments / flat) and its shape. Every
/// change shows on the real bar immediately.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    readonly property var profile: Services.Settings.barFor(Services.Settings.barEditOutput)
    readonly property string widgetStyle: profile.widgetStyle
    readonly property var widgets: profile.left.concat(profile.center, profile.right)

    function setOption(key, value) {
        Services.Settings.setBarValues(Services.Settings.barEditOutput, { [key]: value });
    }

    readonly property bool hasPillSurfaces: widgetStyle === "pills" || widgetStyle === "segments"
        || widgets.some(widget => widget.surface === "pill")
    readonly property bool hasWidgetPadding: widgetStyle !== "polybar" || hasPillSurfaces
        || widgets.some(widget => widget.surface === "plain")

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Monitors"
        visible: Services.Settings.barOutputs.length > 1 || Services.Settings.barLayoutMode === "separate"

        SettingsUi.BarMonitorPicker { width: parent.width }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "The bar"
        description: "The strip along the edge of the screen with the clock, workspaces and other widgets."

        SettingsUi.ChoiceRow {
            title: "Where it sits"
            choices: [{ value: "top", label: "Top", hint: "" }, { value: "bottom", label: "Bottom", hint: "" }]
            value: root.profile.position
            onSelected: value => root.setOption("position", value)
        }

        SettingsUi.SliderRow {
            title: "Height"
            from: 22; to: 48; suffix: " px"
            value: root.profile.height
            onMoved: v => root.setOption("height", Math.round(v))
        }
        SettingsUi.SliderRow {
            title: "Space at the ends"
            description: "Room between the screen's left and right edges and the first and last widget."
            from: 0; to: 48; suffix: " px"
            value: root.profile.padding
            onMoved: v => root.setOption("padding", Math.round(v))
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Widget look"
        description: "How the widgets on the bar are drawn. Each widget can also have its own look under Bar → Widgets."

        SettingsUi.ChoiceRow {
            title: "Style"
            choices: [
                { value: "polybar", label: "Classic", hint: "Plain text with dividers; each widget can have an underline or box." },
                { value: "pills", label: "Pills", hint: "Each widget sits on its own rounded bubble." },
                { value: "segments", label: "Segments", hint: "Neighbouring widgets join into one strip, rounded at its ends. A divider starts a new strip." },
                { value: "flat", label: "Flat", hint: "Just text and icons, with extra room between them." }
            ]
            value: root.profile.widgetStyle
            onSelected: value => root.setOption("widgetStyle", value)
        }

        SettingsUi.SliderRow {
            visible: root.hasWidgetPadding
            title: "Room inside each widget"
            from: 2; to: 20; suffix: " px"
            value: root.profile.pillPadding
            onMoved: v => root.setOption("pillPadding", Math.round(v))
        }
        SettingsUi.SliderRow {
            visible: root.hasWidgetPadding && root.widgetStyle !== "polybar"
            title: "Space between widgets"
            from: 0; to: 20; suffix: " px"
            value: root.profile.widgetGap
            onMoved: v => root.setOption("widgetGap", Math.round(v))
        }
        SettingsUi.SliderRow {
            visible: root.hasPillSurfaces
            title: "Bubble roundness"
            from: 0; to: 16; suffix: " px"
            valueText: value === 0 ? "Square" : ""
            value: root.profile.pillRadius
            onMoved: v => root.setOption("pillRadius", Math.round(v))
        }
        SettingsUi.SliderRow {
            visible: root.hasPillSurfaces
            title: "Bubble shade"
            description: "How much lighter the bubbles are than the bar behind them."
            from: 3; to: 40; suffix: "%"
            value: root.profile.pillTint
            onMoved: v => root.setOption("pillTint", Math.round(v))
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Workspaces"

        Components.SettingsToggle {
            label: "Hide empty workspaces"
            description: "i3 already only lists workspaces that have windows (plus the one you're on), so this rarely changes anything."
            checked: root.profile.hideVacant
            onToggled: v => root.setOption("hideVacant", v)
        }
    }
}
