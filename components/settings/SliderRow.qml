import QtQuick
import ".." as Components

/// An OptionRow holding one StyledSlider. `valueText` replaces the number
/// shown at the end when set (e.g. "Never" for 0).
OptionRow {
    id: row

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string suffix: ""
    property string valueText: ""
    signal moved(real value)

    Components.StyledSlider {
        id: slider
        labelWidth: 0
        from: row.from; to: row.to; stepSize: row.stepSize
        suffix: row.suffix
        value: row.value
        displayValue: row.valueText !== "" ? row.valueText : Math.round(row.value) + row.suffix
        onMoved: value => row.moved(value)
    }
}
