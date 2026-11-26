import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Reusable dropdown/collapsible list — label + current value, click to expand the option list.
Item {
    id: root
    width: parent ? parent.width : 300
    // implicitHeight, not height: a Layout overrides height, which left the
    // expanded list with no room of its own and the rows below painting over
    // it — reading as a see-through list. Item.height follows implicitHeight
    // when nothing sets it, so plain-Column call sites are unaffected.
    implicitHeight: expanded ? 48 + listBox.height + 8 : 48

    property string label: ""
    property var model: []
    property string currentValue: ""
    property var descriptions: ({})
    /// value -> the text shown for it (e.g. a theme slug -> its name); a value
    /// without one shows as itself. The filter matches this text.
    property var labels: ({})
    /// value -> colours drawn as dots after it (a theme's swatches).
    property var swatches: ({})
    /// How tall the open list gets before it scrolls.
    property int maxListHeight: 192
    function labelOf(value) { return root.labels[value] ?? value; }
    property bool expanded: false
    /// Adds a type-to-filter field above the options — for long models (e.g. fonts).
    property bool filterable: false
    property bool paletteSwatches: false
    /// Width of the label column; widen it for long setting names.
    property int labelWidth: 100
    /// Shown while nothing is chosen.
    property string placeholder: "(none)"
    /// Keyboard cursor within shownModel; -1 = nothing highlighted.
    property int highlight: -1
    /// Set by a parent whose own keyboard cursor is on this dropdown, so the
    /// field shows it is next in line to open.
    property bool cursor: false

    // Always an array: a call site whose `model` binding has not evaluated yet
    // would otherwise hand undefined to the indexOf/length reads below.
    readonly property var shownModel: filterable
        ? Services.Fuzzy.filter(model ?? [], filterInput.text, m => root.labelOf(m)) : (model ?? [])

    signal selected(string value)

    /// Open the list and put the cursor on the current value, so a keyboard
    /// user lands where they already are rather than at the top.
    function expand() {
        highlight = indexOfCurrent();
        expanded = true;
        keyScope.forceActiveFocus();
    }

    /// Row of currentValue, or 0 when it is not in the list. Plain arithmetic
    /// rather than Math.max: this runs from onExpandedChanged, which a call
    /// site can trigger during component construction.
    function indexOfCurrent() {
        const i = (shownModel ?? []).indexOf(currentValue);
        return i < 0 ? 0 : i;
    }

    /// Dropping keyScope's focus hands the keyboard back to whichever
    /// FocusScope encloses this one — the settings row cursor, when a host is
    /// driving. Harmless when nothing else wants it.
    function collapse() {
        expanded = false;
        keyScope.focus = false;
    }

    /// Keyboard surface (see SettingsPage). Enter opens the list; Left/Right
    /// steps the value in place without opening, which is what makes a short
    /// enum ("off / fullscreen / always") a one-keypress change.
    function keyActivate() { expand(); }

    function keyAdjust(delta) {
        const list = shownModel ?? [];
        if (!enabled || list.length === 0)
            return;
        const at = list.indexOf(currentValue);
        selected(list[((at < 0 ? 0 : at) + delta + list.length) % list.length]);
    }

    /// Move the cursor, wrapping. Callers: the key handlers below.
    function step(delta) {
        const n = shownModel.length;
        if (n === 0) return;
        highlight = (highlight + delta + n) % n;
        optionsFlick.ensureVisible(highlight);
    }

    function chooseHighlighted() {
        if (highlight >= 0 && highlight < shownModel.length) {
            selected(shownModel[highlight]);
            collapse();
        }
    }

    onExpandedChanged: {
        if (!expanded)
            return;
        highlight = indexOfCurrent();
        if (filterable) {
            filterInput.text = "";
            filterInput.forceActiveFocus();
        }
    }
    // Filtering moves the ground under the cursor; put it back on top.
    onShownModelChanged: if (expanded && highlight >= (shownModel ?? []).length) highlight = 0

    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Holds focus while the list is open so arrows and Enter reach it. Sits
    // outside the visual tree deliberately: the filter field, when there is
    // one, keeps its own focus and forwards through Keys.forwardTo.
    FocusScope {
        id: keyScope
        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)
        Keys.onReturnPressed: root.chooseHighlighted()
        Keys.onEnterPressed: root.chooseHighlighted()
        Keys.onEscapePressed: root.collapse()
    }

    Column {
        width: parent.width
        spacing: 0

        Rectangle {
            width: parent.width
            height: 48
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 12

                StyledText {
                    text: root.label
                    color: root.cursor ? Services.Colors.accent
                                       : Services.Colors.foreground
                    font.pixelSize: Services.Ui.textBodyLarge
                    font.bold: root.cursor
                    Layout.preferredWidth: root.labelWidth
                    visible: root.label !== ""
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Services.Ui.radiusSm
                    color: Services.Colors.color0
                    border.color: root.expanded || root.cursor ? Services.Colors.accent
                                                               : Services.Colors.color8
                    border.width: root.cursor ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6

                        Rectangle {
                            visible: root.paletteSwatches && root.currentValue !== "auto"
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 12
                            radius: 3
                            color: Services.Colors.byKey(root.currentValue, "transparent")
                            border.color: Services.Colors.outline
                        }

                        StyledText {
                            text: root.currentValue ? root.labelOf(root.currentValue) : root.placeholder
                            color: root.currentValue ? Services.Colors.foreground : Services.Colors.color8
                            font.pixelSize: Services.Ui.textBodyLarge
                            Layout.fillWidth: !currentDescription.visible
                            elide: Text.ElideRight
                        }

                        StyledText {
                            id: currentDescription
                            readonly property string description: root.descriptions[root.currentValue] ?? ""
                            visible: description !== ""
                            text: "(" + description + ")"
                            font.pixelSize: Services.Ui.textCaption
                            color: Services.Colors.surfaceVariantText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        SwatchRow {
                            visible: colors.length > 0
                            colors: root.swatches[root.currentValue] ?? []
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: root.expanded ? "▲" : "▼"
                            color: Services.Colors.color8
                            font.pixelSize: Services.Ui.textMicro
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.expanded ? root.collapse() : root.expand()
                    }
                }
            }
        }

        Rectangle {
            id: listBox
            width: parent.width
            height: root.expanded ? (filterRow.height + Math.min(optionsList.count * 32, root.maxListHeight)) : 0
            color: Services.Colors.color0
            border.color: Services.Colors.color8
            border.width: root.expanded ? 1 : 0
            clip: true
            visible: root.expanded

            Column {
                anchors.fill: parent

                Item {
                    id: filterRow
                    width: parent.width
                    height: root.filterable ? 30 : 0
                    visible: root.filterable

                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Services.Colors.foreground
                        font.family: Services.Settings.fontFamily
                        font.pixelSize: Services.Ui.textBody
                        clip: true
                        // Typing filters; the cursor keys and Enter belong to
                        // the list, so they go to the one set of handlers.
                        Keys.onUpPressed: root.step(-1)
                        Keys.onDownPressed: root.step(1)
                        Keys.onEscapePressed: root.collapse()
                        Keys.onReturnPressed: {
                            if (root.shownModel.length > 0) {
                                root.chooseHighlighted();
                            }
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type to filter..."
                        color: Services.Colors.color8
                        font.pixelSize: Services.Ui.textBody
                        visible: filterInput.text.length === 0
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Services.Colors.color8
                    }
                }

                Flickable {
                    id: optionsFlick
                    width: parent.width
                    height: parent.height - filterRow.height
                    contentHeight: optionsCol.implicitHeight
                    clip: true

                    /// Scroll the keyboard cursor into view. Rows are a fixed
                    /// 32px, so this is arithmetic rather than item lookup.
                    function ensureVisible(index) {
                        const top = index * 32;
                        if (top < contentY)
                            contentY = top;
                        else if (top + 32 > contentY + height)
                            contentY = top + 32 - height;
                    }

                    Column {
                        id: optionsCol
                        width: parent.width

                        Repeater {
                            id: optionsList
                            model: root.shownModel

                            delegate: Rectangle {
                                id: optionRow
                                required property string modelData
                                required property int index
                                readonly property bool active: optionHover.containsMouse
                                    || index === root.highlight
                                width: parent.width
                                height: 32
                                color: active
                                    ? Services.Colors.accent
                                    : (modelData === root.currentValue ? Services.Colors.accentAlpha(0.2) : "transparent")

                                Rectangle {
                                    visible: root.paletteSwatches && modelData !== "auto"
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12
                                    height: 12
                                    radius: 3
                                    color: Services.Colors.byKey(modelData, "transparent")
                                    border.color: Services.Colors.outline
                                }

                                RowLayout {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: root.paletteSwatches ? 32 : 12
                                    anchors.rightMargin: 8

                                    StyledText {
                                        text: root.labelOf(optionRow.modelData)
                                        color: optionRow.active ? Services.Colors.background
                                            : (modelData === root.currentValue ? Services.Colors.accent : Services.Colors.foreground)
                                        font.pixelSize: Services.Ui.textBodyLarge
                                        font.bold: modelData === root.currentValue
                                        Layout.fillWidth: !optionDescription.visible
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        id: optionDescription
                                        readonly property string description: root.descriptions[modelData] ?? ""
                                        visible: description !== ""
                                        text: "(" + description + ")"
                                        font.pixelSize: Services.Ui.textCaption
                                        color: optionRow.active ? Services.Colors.background : Services.Colors.surfaceVariantText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    SwatchRow {
                                        visible: colors.length > 0
                                        colors: root.swatches[optionRow.modelData] ?? []
                                    }
                                }

                                MouseArea {
                                    id: optionHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.selected(modelData);
                                        root.collapse();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
