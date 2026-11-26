import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Windows & gaps: i3's window options in plain words. Each setting says what
/// it is and what the current choice does; the ones few people need are under
/// Advanced. Edits are a draft until Apply, which i3 checks before reloading.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16
    // Room for the floating apply bar, so it never covers the last setting.
    trailingScrollPadding: 32 + (floatingBar.visible ? floatingBar.height + 16 : 0)

    property var saved: ({})
    property var draft: ({})
    property string revision: ""
    property string message: ""
    readonly property bool ready: revision !== ""
    readonly property bool dirty: JSON.stringify(saved) !== JSON.stringify(draft)
    readonly property int changeCount: Object.keys(draft)
        .filter(key => JSON.stringify(draft[key]) !== JSON.stringify(saved[key])).length
    readonly property bool editable: ready && !i3Options.running

    function setOption(key, value) {
        draft = Object.assign({}, draft, { [key]: value });
    }

    function setBorderStyle(key, style) {
        const previous = draft[key];
        setOption(key, { style: style,
            width: style === "none" ? 0 : previous?.style === "none" ? 2 : (previous?.width ?? 2) });
    }

    function discard() {
        draft = saved;
        message = "";
    }

    /// The hint for a row's current value, from its choice list.
    function hintFor(choices, value) {
        return choices.find(choice => choice.value === value)?.hint ?? "";
    }

    function run(operation) {
        const args = [];
        if (operation === "apply") {
            const changes = {};
            for (const key in draft)
                if (JSON.stringify(draft[key]) !== JSON.stringify(saved[key]))
                    changes[key] = draft[key];
            args.push(revision, JSON.stringify(changes));
        } else if (operation === "borders") {
            args.push(revision);
        }
        if (i3Options.run(operation, args)) message = "";
    }

    Component.onCompleted: run("list")

    Lib.JsonScript {
        id: i3Options
        script: "i3/i3-window-options.py"
        fallbackError: "Could not read or apply i3 window options."
        onFailed: message => root.message = message
        onSucceeded: (result, operation) => {
            root.saved = result.values;
            root.draft = result.values;
            root.revision = result.revision;
            root.message = result.warning || (operation === "apply" ? "Applied — i3 has reloaded."
                : operation === "borders" ? "Open windows now use these borders." : "");
        }
    }

    // ─── Choice lists (value = i3's word, label/hint = plain words) ───
    readonly property var smartGapChoices: [
        { value: "off", label: "Keep gaps", hint: "Gaps stay the same however many windows are open." },
        { value: "on", label: "No gaps", hint: "A lone window fills the whole screen; gaps come back with a second window." },
        { value: "inverse_outer", label: "Edge gaps only", hint: "Screen-edge gaps show only while a workspace has one window." }
    ]
    readonly property var borderStyleChoices: [
        { value: "pixel", label: "Thin line", hint: "A coloured outline; the focused window's is highlighted." },
        { value: "normal", label: "Title bar", hint: "A bar on top with the window's name, like most desktops." },
        { value: "none", label: "None", hint: "No border at all, so nothing shows which window is focused." }
    ]
    readonly property var edgeBorderChoices: [
        { value: "none", label: "Never", hint: "Borders show on every side of every window." },
        { value: "smart", label: "When one window is open", hint: "A window alone on its workspace has no border." },
        { value: "smart_no_gaps", label: "When one window is open and gaps are off", hint: "Like the above, but only while there are no gaps." },
        { value: "both", label: "Always, on every screen edge", hint: "Borders that touch the screen edge are hidden." },
        { value: "vertical", label: "Always, left and right edges", hint: "Borders touching the left or right screen edge are hidden." },
        { value: "horizontal", label: "Always, top and bottom edges", hint: "Borders touching the top or bottom screen edge are hidden." }
    ]
    readonly property var focusChoices: [
        { value: "no", label: "When I click it", hint: "Like most desktops: moving the mouse never changes the focused window." },
        { value: "yes", label: "When the mouse moves over it", hint: "Point at a window to type into it — no click needed." }
    ]
    readonly property var activationChoices: [
        { value: "smart", label: "Switch if visible", hint: "Focus it if it's on screen; otherwise mark it as needing attention." },
        { value: "urgent", label: "Just mark it", hint: "Never steal focus; the workspace is highlighted in the bar instead." },
        { value: "focus", label: "Always switch", hint: "Jump straight to it, even on another workspace." },
        { value: "none", label: "Ignore", hint: "Do nothing at all." }
    ]
    readonly property var layoutChoices: [
        { value: "default", label: "Side by side", hint: "New windows split the screen with the ones already there." },
        { value: "stacking", label: "Stacked", hint: "One window at a time, with a list of titles above it." },
        { value: "tabbed", label: "Tabbed", hint: "One window at a time, with tabs across the top like a browser." }
    ]
    readonly property var titleAlignChoices: [
        { value: "left", label: "Left", hint: "" },
        { value: "center", label: "Centre", hint: "" },
        { value: "right", label: "Right", hint: "" }
    ]
    readonly property var wrapChoices: [
        { value: "yes", label: "Wrap around", hint: "Moving focus past the last window comes back round to the first (unless a window sits further that way)." },
        { value: "no", label: "Stop at the edge", hint: "Focus stops at the last window in that direction." },
        { value: "force", label: "Always wrap", hint: "Wrap within the current split, even when another window is further that way." },
        { value: "workspace", label: "Within workspace", hint: "Wrap round, but never jump to another monitor." }
    ]
    readonly property var fullscreenPopupChoices: [
        { value: "smart", label: "From the same app", hint: "Dialogs from the fullscreen app appear; others wait." },
        { value: "ignore", label: "Hide them", hint: "Stay fullscreen; popups wait until you leave." },
        { value: "leave_fullscreen", label: "Exit fullscreen", hint: "Any popup takes you out of fullscreen." },
        { value: "all", label: "Show all", hint: "Every popup appears on top of the fullscreen window." }
    ]

    // ─── Not set up ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: i3Options.lastResult?.setup === true
        title: "One-time setup needed"
        description: (i3Options.lastResult?.error ?? "") + " Setting up adds a small file next to your "
            + "i3 config (in modules/) and one line to include it. i3 checks the result before anything is saved."
        Components.TextButton {
            text: "Set up"
            enabled: !i3Options.running
            onClicked: root.run("setup")
        }
    }

    // ─── Intro + apply ───
    Components.Card {
        id: statusCard
        x: root.horizontalPadding
        width: root.rowWidth
        title: "How your windows look and behave"
        description: "Changes wait here until you press Apply. i3 checks them first, so a mistake can't "
            + "break your setup. Settings you haven't changed use i3's defaults."

        Row {
            spacing: 8
            visible: root.dirty

            Components.TextButton {
                text: root.changeCount === 1 ? "Apply 1 change" : "Apply " + root.changeCount + " changes"
                fontBold: true
                idleColor: Services.Colors.accent
                idleTextColor: Services.Colors.background
                enabled: root.ready && !i3Options.running
                onClicked: root.run("apply")
            }
            Components.TextButton {
                text: "Discard"
                enabled: !i3Options.running
                onClicked: root.discard()
            }
        }

        Components.StyledText {
            width: parent.width
            text: i3Options.running ? "Working…" : root.message
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
        }
    }

    // ─── Gaps ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Gaps"
        description: "Empty space between windows, so you can see your wallpaper around them."
        enabled: root.editable

        SettingsUi.OptionRow {
            title: "Between windows"
            description: "Also counts towards the space at the screen edges."
            Components.StyledSlider {
                labelWidth: 0
                from: 0; to: 64; suffix: " px"
                value: root.draft.inner ?? 0
                onMoved: value => root.setOption("inner", Math.round(value))
            }
        }

        SettingsUi.OptionRow {
            title: "Extra space at the screen edges"
            description: "Added to the gap above. Go below zero to pull windows closer to the edge."
            Components.StyledSlider {
                labelWidth: 0
                from: -64; to: 64; suffix: " px"
                value: root.draft.outer ?? 0
                onMoved: value => root.setOption("outer", Math.round(value))
            }
        }

        SettingsUi.OptionRow {
            title: "When a workspace has only one window"
            hint: root.hintFor(root.smartGapChoices, root.draft.smartGaps ?? "off")
            Components.SegmentedControl {
                model: root.smartGapChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.smartGaps ?? "off"
                onSelected: value => root.setOption("smartGaps", value)
            }
        }
    }

    // ─── Borders ───
    Components.Card {
        id: bordersCard
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Borders"
        description: "The frame around each window. Its colour comes from your theme."
        enabled: root.editable

        Repeater {
            model: [
                { key: "tilingBorder", title: "Tiled windows",
                  description: "Windows that share the screen — the usual kind." },
                { key: "floatingBorder", title: "Floating windows",
                  description: "Windows that hover on top, like dialogs and popups." }
            ]

            delegate: SettingsUi.OptionRow {
                id: borderRow
                required property var modelData
                readonly property var border: root.draft[modelData.key] ?? ({ style: "pixel", width: 2 })
                title: modelData.title
                description: modelData.description

                Column {
                    width: parent.width
                    spacing: 6

                    Components.SegmentedControl {
                        model: root.borderStyleChoices
                        valueRole: "value"; textRole: "label"
                        currentValue: borderRow.border.style
                        onSelected: value => root.setBorderStyle(borderRow.modelData.key, value)
                    }
                    // The style's hint sits under its buttons, above Thickness.
                    Components.StyledText {
                        width: parent.width
                        text: root.hintFor(root.borderStyleChoices, borderRow.border.style)
                        color: Services.Colors.accent
                        font.pixelSize: Services.Ui.textSmall
                        wrapMode: Text.WordWrap
                    }
                    Components.StyledSlider {
                        label: "Thickness"
                        labelWidth: 90
                        visible: borderRow.border.style !== "none"
                        from: 1; to: 16; suffix: " px"
                        value: borderRow.border.width
                        onMoved: value => root.setOption(borderRow.modelData.key,
                            { style: borderRow.border.style, width: Math.round(value) })
                    }
                }
            }
        }

        SettingsUi.OptionRow {
            title: "Hide borders at the screen edges"
            description: "Saves a few pixels where a border would only touch the edge of the screen."
            hint: root.hintFor(root.edgeBorderChoices, root.draft.edgeBorders ?? "none")
            Components.StyledDropdown {
                id: edgeBorderPicker
                labelWidth: 0
                model: root.edgeBorderChoices.map(choice => choice.label)
                currentValue: root.edgeBorderChoices.find(choice => choice.value === root.draft.edgeBorders)?.label ?? ""
                onSelected: label => root.setOption("edgeBorders",
                    root.edgeBorderChoices.find(choice => choice.label === label).value)
            }
        }
    }

    // ─── Focus ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Focus"
        description: "The focused window is the one your typing goes to."
        enabled: root.editable

        SettingsUi.OptionRow {
            title: "Focus a window"
            hint: root.hintFor(root.focusChoices, root.draft.focusFollowsMouse ?? "yes")
            Components.SegmentedControl {
                model: root.focusChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.focusFollowsMouse ?? "yes"
                onSelected: value => root.setOption("focusFollowsMouse", value)
            }
        }

        SettingsUi.OptionRow {
            title: "When an app asks for your attention"
            description: "For example a chat app with a new message, or a link opening in your browser."
            hint: root.hintFor(root.activationChoices, root.draft.focusOnActivation ?? "smart")
            Components.SegmentedControl {
                model: root.activationChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.focusOnActivation ?? "smart"
                onSelected: value => root.setOption("focusOnActivation", value)
            }
        }

        Components.SettingsToggle {
            label: "Move the mouse to the focused monitor"
            description: "When the keyboard moves focus to another monitor, the pointer jumps there too."
            checked: (root.draft.mouseWarping ?? "output") === "output"
            onToggled: checked => root.setOption("mouseWarping", checked ? "output" : "none")
        }
    }

    // ─── Layout ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Layout"
        enabled: root.editable

        SettingsUi.OptionRow {
            title: "How a new workspace arranges windows"
            description: "You can still change any workspace's layout with the keyboard."
            hint: root.hintFor(root.layoutChoices, root.draft.workspaceLayout ?? "default")
            Components.SegmentedControl {
                model: root.layoutChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.workspaceLayout ?? "default"
                onSelected: value => root.setOption("workspaceLayout", value)
            }
        }

        SettingsUi.OptionRow {
            title: "Title text position"
            description: "Where the name sits on title bars and tabs."
            Components.SegmentedControl {
                model: root.titleAlignChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.titleAlign ?? "left"
                onSelected: value => root.setOption("titleAlign", value)
            }
        }
    }

    // ─── Advanced ───
    Components.Card {
        id: advancedCard
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Advanced"
        description: "Settings most people never need to change."
        collapsible: true
        expanded: false
        enabled: root.editable

        SettingsUi.OptionRow {
            title: "Moving focus past the last window"
            hint: root.hintFor(root.wrapChoices, root.draft.focusWrapping ?? "yes")
            Components.SegmentedControl {
                model: root.wrapChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.focusWrapping ?? "yes"
                onSelected: value => root.setOption("focusWrapping", value)
            }
        }

        SettingsUi.OptionRow {
            title: "Popups while a window is fullscreen"
            description: "For example a dialog appearing while you watch a video or play a game."
            hint: root.hintFor(root.fullscreenPopupChoices, root.draft.fullscreenPopups ?? "smart")
            Components.SegmentedControl {
                model: root.fullscreenPopupChoices
                valueRole: "value"; textRole: "label"
                currentValue: root.draft.fullscreenPopups ?? "smart"
                onSelected: value => root.setOption("fullscreenPopups", value)
            }
        }

        Components.SettingsToggle {
            label: "Show window marks"
            description: "Marks are labels you can give windows with i3 commands, to jump back to them later."
            checked: (root.draft.showMarks ?? "yes") === "yes"
            onToggled: checked => root.setOption("showMarks", checked ? "yes" : "no")
        }

        SettingsUi.OptionRow {
            title: "Reset open windows' borders"
            description: "Windows whose border you changed by hand keep it. This puts every open window back "
                + "to the border settings above."
            Components.TextButton {
                text: "Reset borders"
                enabled: !root.dirty
                onClicked: root.run("borders")
            }
        }

        SettingsUi.OptionRow {
            title: "Reload from the i3 config"
            description: "Use this if you edited modules/window-options.config by hand. Unapplied changes here are lost."
            Components.TextButton {
                text: "Reload"
                enabled: !i3Options.running
                onClicked: root.run("list")
            }
        }
    }

    // ─── Floating apply bar ───
    // Shown once the intro card's buttons have scrolled out of sight. It sits
    // on the Flickable itself, not its content, so it stays put while scrolling.
    Rectangle {
        id: floatingBar
        parent: root
        z: 10
        visible: root.dirty && root.contentY > statusCard.y + statusCard.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: barRow.implicitWidth + 32
        height: barRow.implicitHeight + 20
        radius: Services.Ui.radiusLg
        color: Services.Ui.panelColor
        border.color: Services.Colors.accent
        border.width: 1

        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 12

            Components.StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.changeCount === 1 ? "1 unsaved change" : root.changeCount + " unsaved changes"
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBody
            }
            Components.TextButton {
                text: "Apply"
                fontBold: true
                idleColor: Services.Colors.accent
                idleTextColor: Services.Colors.background
                enabled: root.ready && !i3Options.running
                onClicked: root.run("apply")
            }
            Components.TextButton {
                text: "Discard"
                enabled: !i3Options.running
                onClicked: root.discard()
            }
        }
    }
}
