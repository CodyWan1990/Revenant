import QtQuick
import "../services" as Services

/// A row of small colour dots: a theme's swatches (Services.Theme.themes[].swatches).
Row {
    id: root
    property var colors: []
    property int size: 10
    spacing: 3
    Repeater {
        model: root.colors
        Rectangle {
            required property string modelData
            width: root.size; height: root.size; radius: root.size / 2
            color: modelData
            border.color: Services.Colors.outlineVariant
            border.width: 1
        }
    }
}
