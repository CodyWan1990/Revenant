import QtQuick
import "../../services" as Services
import ".." as Components

/// Same bar everywhere, or one per monitor — and, for the latter, which
/// monitor's bar the page is editing. Shared by Bar → Appearance and Widgets.
Column {
    id: root
    spacing: 8

    readonly property var settings: Services.Settings
    readonly property bool separate: settings.barLayoutMode === "separate"

    ChoiceRow {
        width: parent.width
        title: "With more than one monitor"
        choices: [
            { value: "shared", label: "Same bar everywhere",
              hint: "Every monitor shows the same bar. Changes here apply to all of them." },
            { value: "separate", label: "Each monitor its own",
              hint: "Every monitor can have its own widgets and look. Pick which one to change below." }
        ]
        value: root.settings.barLayoutMode
        onSelected: value => root.settings.setBarLayoutMode(value)
    }

    OptionRow {
        width: parent.width
        visible: root.separate && root.settings.barOutputs.length > 0
        title: "Changing the bar on"
        Components.StyledDropdown {
            width: parent.width
            labelWidth: 0
            model: root.settings.barOutputs
            currentValue: root.settings.barEditOutput
            onSelected: value => root.settings.preferredBarOutput = value
        }
    }
}
