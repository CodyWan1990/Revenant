import QtQuick
import "../services" as Services
import "../components" as Components

/// Fixed-width gap with an optional centred glyph (types "separator" and the legacy "spacer").
Item {
    id: sepRoot
    property var bar: null
    property var instance: ({})
    readonly property string glyph: instance.hideGlyph ? "" : (instance.glyph ?? "")
    implicitWidth: Services.Settings.separatorWidth(instance)
    implicitHeight: glyph === "" ? 1 : sepText.implicitHeight
    clip: true

    Components.StyledText {
        id: sepText
        anchors.centerIn: parent
        visible: sepRoot.glyph !== ""
        text: sepRoot.glyph
        color: Services.Colors.byKey(sepRoot.instance.color, Services.Colors.surfaceVariantText)
        font.pixelSize: (sepRoot.instance.glyphSize ?? 0) || Services.Settings.fontSize
    }
}
