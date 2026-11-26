import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services" as Services
import "../components" as Components

/// Keybind cheat sheet, modelled on Dux Shell's keybinds modal (MIT): every
/// i3 binding (scripts/i3/keybinds.py), grouped by the config's own
/// section comments, keys drawn as keycaps. Type to filter; Esc closes.
Components.OverlayPanel {
    id: panel

    property var binds: []      // [{ section, keys, action, source, note }]

    readonly property var groups: {
        const q = search.text.trim().toLowerCase();
        const hit = b => q === "" || b.keys.toLowerCase().includes(q) || b.action.toLowerCase().includes(q)
            || b.section.toLowerCase().includes(q) || (b.note || "").toLowerCase().includes(q);
        const out = [];
        for (const b of binds) {
            if (!hit(b)) continue;
            let g = out.find(x => x.name === b.section);
            if (!g) { g = { name: b.section, items: [] }; out.push(g); }
            g.items.push(b);
        }
        return out;
    }

    onOpened: { search.text = ""; load.running = true; flick.contentY = 0; }
    onFocusRequested: search.forceActiveFocus()

    Process {
        id: load
        command: ["python3", Services.Paths.script("i3/keybinds.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { panel.binds = JSON.parse(this.text); }
                catch (e) { console.warn("Keybinds: bad JSON", e); }
            }
        }
    }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: 900
        height: 680
        opacity: panel.contentOpacity

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Components.StyledText {
                    text: "Keybinds"
                    color: Services.Colors.foreground
                    font.pixelSize: Services.Ui.textHeading
                    font.bold: true
                    Layout.fillWidth: true
                }
                Components.StyledText {
                    text: panel.binds.length + " i3 bindings"
                    color: Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textSmall
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: Services.Colors.surfaceContainerHigh

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: Services.Colors.foreground
                    font.family: Services.Settings.fontFamily
                    font.pixelSize: Services.Ui.textBodyLarge
                    clip: true
                    Keys.onEscapePressed: panel.close()
                    Keys.onDownPressed: flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + 60)
                    Keys.onUpPressed: flick.contentY = Math.max(0, flick.contentY - 60)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) {
                            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + flick.height * 0.8);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            flick.contentY = Math.max(0, flick.contentY - flick.height * 0.8);
                            event.accepted = true;
                        }
                    }
                }
                Components.StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search keys or actions"
                    color: Services.Colors.color8
                    font.pixelSize: Services.Ui.textBodyLarge
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: groupsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: groupsCol
                    width: flick.width
                    spacing: 12

                    Repeater {
                        model: panel.groups

                        delegate: Components.Card {
                            id: groupCard
                            required property var modelData
                            width: groupsCol.width
                            title: modelData.name

                            Repeater {
                                // Card moves children into its own column, so
                                // reach the group by id, not parent.parent.
                                model: groupCard.modelData.items

                                delegate: RowLayout {
                                    id: bindRow
                                    required property var modelData
                                    width: parent.width
                                    spacing: 12

                                    // Keycaps
                                    Row {
                                        Layout.preferredWidth: 260
                                        spacing: 4
                                        Repeater {
                                            model: bindRow.modelData.keys.split(" + ")
                                            Rectangle {
                                                required property string modelData
                                                width: Math.max(24, cap.implicitWidth + 14)
                                                height: 24
                                                radius: 6
                                                color: Services.Colors.surfaceContainerHighest
                                                border.color: Services.Colors.outlineVariant
                                                border.width: 1
                                                Components.StyledText {
                                                    id: cap
                                                    anchors.centerIn: parent
                                                    text: parent.modelData
                                                    color: Services.Colors.foreground
                                                    font.pixelSize: Services.Ui.textSmall
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Components.StyledText {
                                            width: parent.width
                                            text: bindRow.modelData.action
                                            color: Services.Colors.foreground
                                            font.pixelSize: Services.Ui.textBody
                                            elide: Text.ElideRight
                                        }
                                        Components.StyledText {
                                            width: parent.width
                                            visible: (bindRow.modelData.note || "") !== ""
                                            text: bindRow.modelData.note || ""
                                            color: Services.Colors.surfaceVariantText
                                            font.pixelSize: Services.Ui.textCaption
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Components.StyledText {
                text: "Type to filter · ↑↓ / PgUp PgDn scroll · Esc close"
                color: Services.Colors.color8
                font.pixelSize: Services.Ui.textSmall
            }
        }
    }
}
