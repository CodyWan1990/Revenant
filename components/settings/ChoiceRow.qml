import QtQuick
import ".." as Components

/// An OptionRow holding one SegmentedControl. `choices` is a list of
/// { value, label, hint }: the buttons show the labels, and the line under them
/// says what the current choice does.
OptionRow {
    id: row

    property var choices: []
    property string value: ""
    signal selected(string value)

    hint: choices.find(choice => choice.value === value)?.hint ?? ""

    Components.SegmentedControl {
        model: row.choices
        valueRole: "value"; textRole: "label"
        currentValue: row.value
        onSelected: value => row.selected(value)
    }
}
