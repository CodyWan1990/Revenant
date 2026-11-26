import QtQuick
import "../../services" as Services

/// The screenshot selector's toolbar (panels/ScreenshotSelector.qml): drawing
/// tools, colours, undo and the copy / save actions, or the file-name field
/// while naming. Places itself below the selection, else above it, else inside,
/// on the selection's monitor.
Rectangle {
    id: root
    visible: selector.selection !== null && !selector.busy
    width: toolColumn.implicitWidth + 12
    height: toolColumn.implicitHeight + 12
    color: Services.Colors.background
    border.color: Services.Colors.outlineVariant

    required property var selector

    /// Show the name field for `action` (save | both | open), filled in.
    function startNaming(text) {
        nameField.text = text;
        nameField.selectAll();
        nameField.forceActiveFocus();
    }
    function focusName() { nameField.forceActiveFocus(); }

    readonly property var s: selector.selection ?? { x: 0, y: 0, w: 0, h: 0 }
    readonly property var mon: selector.monitorFor(s)
    readonly property int gap: 10
    x: Math.max(mon.x + 8, Math.min(mon.x + mon.w - width - 8, s.x + s.w - width))
    y: s.y + s.h + gap + height <= mon.y + mon.h ? s.y + s.h + gap
        : s.y - gap - height >= mon.y ? s.y - gap - height
        : s.y + s.h - height - gap

    Column {
        id: toolColumn
        x: 6; y: 6
        spacing: 6

        Row {
            id: toolRow
            visible: !selector.naming
            spacing: 4
            IconToolButton { glyph: ""; tipText: "Move / resize  (V)"; checked: selector.tool === "select"; onClicked: selector.tool = "select" }
            IconToolButton { glyph: ""; tipText: "Pen  (P)"; checked: selector.tool === "pen"; onClicked: selector.tool = "pen" }
            IconToolButton { glyph: ""; tipText: "Arrow  (A)"; checked: selector.tool === "arrow"; onClicked: selector.tool = "arrow" }
            IconToolButton { glyph: ""; tipText: "Rectangle  (R)"; checked: selector.tool === "rect"; onClicked: selector.tool = "rect" }
            IconToolButton { glyph: ""; tipText: "Highlighter  (M)"; checked: selector.tool === "marker"; onClicked: selector.tool = "marker" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: Services.Colors.outlineVariant }
            Repeater {
                model: selector.inks
                Rectangle {
                    required property color modelData
                    required property int index
                    readonly property bool hovered: swatchArea.containsMouse
                    readonly property string tipText: "Colour  (" + (index + 1) + ")"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22
                    color: "transparent"
                    border.color: selector.inkIndex === index ? Services.Colors.foreground : "transparent"
                    border.width: 2
                    Rectangle { anchors.fill: parent; anchors.margins: 4; color: parent.modelData }
                    MouseArea {
                        id: swatchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: selector.inkIndex = parent.index
                    }
                }
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: Services.Colors.outlineVariant }
            IconToolButton { glyph: ""; tipText: "Undo  (Ctrl+Z)"; enabled: selector.shapes.length > 0; onClicked: selector.undo() }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: Services.Colors.outlineVariant }
            IconToolButton { glyph: ""; label: "Copy"; tipText: "Copy to clipboard  (Enter, Ctrl+C, double-click)"; tint: Services.Colors.color4; onClicked: selector.finish("copy") }
            IconToolButton { glyph: ""; label: "Save"; tipText: "Save to " + selector.saveDir + "  (Ctrl+S)"; tint: Services.Colors.color2; onClicked: selector.finish("save") }
            IconToolButton { glyph: ""; label: "Both"; tipText: "Copy and save  (Shift+Enter, Ctrl+Shift+S)"; tint: Services.Colors.color6; onClicked: selector.finish("both") }
            IconToolButton { glyph: ""; tipText: "Save and open  (Ctrl+O)"; onClicked: selector.finish("open") }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: Services.Colors.outlineVariant }
            IconToolButton { glyph: ""; tipText: "Cancel  (Esc, right-click: reselect)"; tint: Services.Colors.color1; onClicked: selector.cancel() }
        }

        // ─── File name, when Settings → Screenshots asks for one ───
        Row {
            id: nameRow
            visible: selector.naming !== ""
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Name"
                color: Services.Colors.foreground
                font.family: selector.fontFamily
                font.pixelSize: Services.Ui.textBody
                font.bold: true
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 380; height: 30
                color: Services.Colors.color0
                border.color: nameField.activeFocus ? selector.accent : Services.Colors.outlineVariant
                border.width: nameField.activeFocus ? 2 : 1
                TextInput {
                    id: nameField
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    color: Services.Colors.foreground
                    selectionColor: selector.accent
                    selectedTextColor: Services.Colors.background
                    font.family: selector.fontFamily
                    font.pixelSize: Services.Ui.textBody
                    Keys.onReturnPressed: selector.finish(selector.naming, text)
                    Keys.onEnterPressed: selector.finish(selector.naming, text)
                    Keys.onEscapePressed: selector.stopNaming()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ".png"
                color: Services.Colors.surfaceVariantText
                font.family: selector.fontFamily
                font.pixelSize: Services.Ui.textBody
            }
            IconToolButton {
                glyph: "\uf0c7"
                label: selector.naming === "both" ? "Copy + save" : selector.naming === "open" ? "Save + open" : "Save"
                tipText: "Save to " + selector.saveDir + "  (Enter)"
                tint: Services.Colors.color2
                onClicked: selector.finish(selector.naming, nameField.text)
            }
            IconToolButton {
                glyph: "\uf060"
                tipText: "Back to editing  (Esc)"
                onClicked: selector.stopNaming()
            }
        }

        Text {
            // The hovered button's tip.
            text: {
                if (selector.naming && !nameRow.children.some(c => c.hovered))
                    return "Saving to " + selector.saveDir + "  ·  Enter saves  ·  Esc goes back";
                for (const c of (selector.naming ? nameRow : toolRow).children)
                    if (c.hovered) return c.tipText;
                return "Arrows move (Shift ×10)  ·  1–5 colour  ·  Enter copies";
            }
            color: Services.Colors.surfaceVariantText
            font.family: selector.fontFamily
            font.pixelSize: Services.Ui.textCaption
        }
    }
}
