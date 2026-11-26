import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var saved: []
    property var draft: []
    property double deadline: 0
    property int secondsRemaining: 0
    readonly property bool awaitingConfirmation: deadline > 0
    readonly property bool confirmingMonitorLayout: awaitingConfirmation || (worker.running && worker.operation === "apply")
    property string outputName: ""
    property string message: ""
    readonly property var selected: draft.find(output => output.name === outputName)
    readonly property var active: draft.filter(output => output.enabled)
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(saved)

    function update(patch) {
        draft = draft.map(output => output.name === outputName ? Object.assign({}, output, patch) : output);
    }

    function run(operation) {
        const args = [Services.Paths.monitorLayoutPath];
        if (operation === "apply") args.push(JSON.stringify({ saved, draft }));
        if (operation === "keep" || operation === "revert") args.push(String(deadline));
        if (worker.run(operation, args)) message = "";
    }

    Component.onCompleted: run("read")

    function updateCountdown() {
        secondsRemaining = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
        if (!secondsRemaining && !worker.running) run("revert");
    }

    Timer {
        interval: 250
        repeat: true
        running: root.awaitingConfirmation
        onTriggered: root.updateCountdown()
    }

    Lib.JsonScript {
        id: worker
        script: "i3/monitor-layout.py"
        fallbackError: "Could not read the monitor layout."
        onFailed: message => root.message = message
        onSucceeded: (result, operation) => {
            root.deadline = result.deadline ?? 0;
            if (root.awaitingConfirmation)
                root.secondsRemaining = Math.max(0, Math.ceil((root.deadline - Date.now()) / 1000));
            root.saved = result.outputs;
            root.draft = result.outputs;
            if (!root.selected)
                root.outputName = root.active[0]?.name ?? root.draft[0]?.name ?? "";
            root.message = result.status === "kept" ? "Monitor layout kept for this session."
                : result.status === "reverted" || result.status === "expired" ? "Previous layout restored."
                : operation === "save" ? "Layout saved for future sessions."
                : root.draft.length ? "" : "No connected monitors found.";
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Arrange your monitors"
        description: "Drag the boxes to match where your screens sit on your desk, and click one to change it below. "
            + "Nothing changes until you press Apply — and if the picture goes wrong, it switches back by itself."

        Rectangle {
            id: map
            width: parent.width
            height: 250
            color: Services.Colors.background
            border.color: Services.Colors.outlineVariant
            radius: Services.Ui.radiusSm
            clip: true

            property bool dragging: false
            property real dragScale: 1
            function extent(output, vertical) {
                const dimensions = output.mode.split("x");
                const sideways = output.rotation === "left" || output.rotation === "right";
                return Number(dimensions[vertical !== sideways ? 1 : 0]) || 1;
            }
            function snap(output, x, y) {
                const width = extent(output, false);
                const height = extent(output, true);
                const threshold = 12 / dragScale;
                let dx = threshold;
                let dy = threshold;
                for (const other of root.active) {
                    if (other.name === output.name) continue;
                    const right = other.x + extent(other, false);
                    const bottom = other.y + extent(other, true);
                    if (y <= bottom + threshold && y + height >= other.y - threshold) {
                        for (const edge of [other.x - width, other.x, right - width, right]) {
                            if (Math.abs(edge - x) < Math.abs(dx)) dx = edge - x;
                        }
                    }
                    if (x <= right + threshold && x + width >= other.x - threshold) {
                        for (const edge of [other.y - height, other.y, bottom - height, bottom]) {
                            if (Math.abs(edge - y) < Math.abs(dy)) dy = edge - y;
                        }
                    }
                }
                return Qt.point(Math.round(x + (Math.abs(dx) < threshold ? dx : 0)),
                    Math.round(y + (Math.abs(dy) < threshold ? dy : 0)));
            }

            readonly property real minX: Math.min(0, ...root.active.map(output => output.x))
            readonly property real minY: Math.min(0, ...root.active.map(output => output.y))
            readonly property real maxX: Math.max(1, ...root.active.map(output => output.x + extent(output, false)))
            readonly property real maxY: Math.max(1, ...root.active.map(output => output.y + extent(output, true)))
            readonly property real scaleFactor: Math.max(0.001, Math.min(
                (width - 32) / (maxX - minX), (height - 32) / (maxY - minY)))

            Repeater {
                model: root.active

                Rectangle {
                    id: screenTile
                    required property var modelData
                    x: 16 + (modelData.x - map.minX) * map.scaleFactor
                    y: 16 + (modelData.y - map.minY) * map.scaleFactor
                    width: map.extent(modelData, false) * map.scaleFactor
                    height: map.extent(modelData, true) * map.scaleFactor
                    color: modelData.name === root.outputName ? Services.Colors.primaryContainer : Services.Ui.cardColor
                    border.color: modelData.name === root.outputName ? Services.Colors.accent : Services.Colors.outlineVariant
                    radius: Services.Ui.radiusSm
                    z: drag.active ? 2 : modelData.name === root.outputName ? 1 : 0
                    clip: true

                    Components.StyledText {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 8)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: screenTile.modelData.name + (screenTile.modelData.primary ? " ★" : "")
                        color: screenTile.modelData.name === root.outputName
                            ? Services.Colors.primaryContainerText : Services.Colors.foreground
                    }

                    DragHandler {
                        id: drag
                        enabled: !worker.running && !root.awaitingConfirmation
                        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        target: null
                        property point offset: Qt.point(0, 0)
                        readonly property point snapped: map.snap(screenTile.modelData,
                            screenTile.modelData.x + activeTranslation.x / map.dragScale,
                            screenTile.modelData.y + activeTranslation.y / map.dragScale)
                        onActiveTranslationChanged: if (active) offset = snapped
                        onActiveChanged: {
                            if (active) {
                                root.outputName = screenTile.modelData.name;
                                map.dragScale = map.scaleFactor;
                                offset = Qt.point(screenTile.modelData.x, screenTile.modelData.y);
                                map.dragging = true;
                            } else if (map.dragging) {
                                map.dragging = false;
                                root.update({
                                    x: offset.x,
                                    y: offset.y
                                });
                            }
                        }
                    }

                    transform: Translate {
                        x: drag.active ? (drag.offset.x - screenTile.modelData.x) * map.dragScale : 0
                        y: drag.active ? (drag.offset.y - screenTile.modelData.y) * map.dragScale : 0
                    }

                    TapHandler { onTapped: root.outputName = screenTile.modelData.name }
                }
            }
        }

        Components.StyledText {
            width: parent.width
            visible: root.awaitingConfirmation
            text: "Does everything look right? If you do nothing, the old setup comes back in "
                + root.secondsRemaining + " seconds."
            wrapMode: Text.WordWrap
            font.bold: true
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: root.awaitingConfirmation
            Components.TextButton {
                text: "Yes, keep it"
                enabled: !worker.running && root.secondsRemaining > 0
                onClicked: root.run("keep")
            }
            Components.TextButton {
                text: "No, go back"
                enabled: !worker.running
                onClicked: root.run("revert")
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            visible: !root.awaitingConfirmation
            Components.TextButton {
                text: "Apply"
                fontBold: true
                idleColor: enabled ? Services.Colors.accent : Services.Ui.fieldColor
                idleTextColor: enabled ? Services.Colors.background : Services.Colors.foreground
                enabled: !worker.running && root.dirty && root.active.length > 0
                onClicked: root.run("apply")
            }
            Components.TextButton {
                text: "Undo changes"
                enabled: !worker.running && root.dirty
                onClicked: root.draft = root.saved
            }
            Components.TextButton {
                text: "Use this every time I log in"
                enabled: !worker.running && !root.dirty && root.active.length > 0
                onClicked: root.run("save")
            }
            Components.TextButton {
                text: "Reload"
                enabled: !worker.running
                onClicked: root.run("read")
            }
        }

        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: worker.running ? "Reading monitor layout…" : root.message
            wrapMode: Text.WordWrap
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Monitor"
        description: "Monitors are named after the socket they're plugged into."
        visible: root.draft.length > 0
        enabled: !worker.running && !root.awaitingConfirmation

        SettingsUi.OptionRow {
            title: "Changing"
            Components.StyledDropdown {
                width: parent.width
                labelWidth: 0
                model: root.draft.map(output => output.name)
                currentValue: root.outputName
                onSelected: name => root.outputName = name
            }
        }

        Components.SettingsToggle {
            label: "Use this monitor"
            description: "Turn off to leave it dark. At least one monitor stays on."
            checked: root.selected?.enabled ?? false
            enabled: !checked || root.active.length > 1
            onToggled: value => root.update({ enabled: value })
        }

        Components.SettingsToggle {
            label: "Main monitor"
            description: "Your main screen: some apps open on it first."
            checked: root.selected?.primary ?? false
            enabled: (root.selected?.enabled ?? false) && !checked
            onToggled: root.draft = root.draft.map(output =>
                Object.assign({}, output, { primary: output.name === root.outputName }))
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Picture"
        visible: root.draft.length > 0
        enabled: !worker.running && !root.awaitingConfirmation

        SettingsUi.OptionRow {
            title: "Resolution"
            description: "How many dots make up the picture. The first one listed is usually the monitor's best."
            Components.StyledDropdown {
                width: parent.width
                labelWidth: 0
                model: Object.keys(root.selected?.modes ?? {})
                currentValue: root.selected?.mode ?? ""
                onSelected: mode => root.update({ mode, rate: root.selected.modes[mode][0] })
            }
        }

        SettingsUi.OptionRow {
            title: "Refresh rate (Hz)"
            description: "How many times a second the picture is redrawn. Higher looks smoother, if the monitor supports it."
            Components.StyledDropdown {
                width: parent.width
                labelWidth: 0
                model: root.selected?.modes?.[root.selected.mode] ?? []
                currentValue: root.selected?.rate ?? ""
                onSelected: rate => root.update({ rate })
            }
        }

        SettingsUi.ChoiceRow {
            title: "Rotation"
            description: "For a monitor turned on its side."
            choices: [
                { value: "normal", label: "Normal", hint: "" },
                { value: "left", label: "Turned left", hint: "The top of the picture faces left." },
                { value: "right", label: "Turned right", hint: "The top of the picture faces right." },
                { value: "inverted", label: "Upside down", hint: "" }
            ]
            value: root.selected?.rotation ?? "normal"
            onSelected: value => root.update({ rotation: value })
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Exact position"
        description: "Where this monitor's top-left corner sits, in pixels. Dragging above does the same thing."
        collapsible: true
        expanded: false
        visible: root.draft.length > 0
        enabled: !worker.running && !root.awaitingConfirmation

        Repeater {
            model: ["x", "y"]
            Components.LabeledSettingRow {
                required property string modelData
                width: parent.width
                label: modelData === "x" ? "From the left" : "From the top"
                labelWidth: 130
                Components.SettingField {
                    width: parent.width
                    text: String(root.selected?.[modelData] ?? 0)
                    onEdited: value => {
                        const number = Number(value);
                        if (value.trim() && Number.isInteger(number))
                            root.update({ [modelData]: number });
                        else
                            text = String(root.selected?.[modelData] ?? 0);
                    }
                }
            }
        }
    }
}
