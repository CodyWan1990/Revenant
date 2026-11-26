import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Settings → System → Systemd, written for people who have never heard of
/// systemd (scripts/system/services.py does the work):
///   About         what services are, and a banner when one has failed
///   Add a service a guided form: checks the program exists as you type and
///                 shows what will run before anything is created
///   Your services / System services
///                 compact rows (ServiceRow) with plain statuses; click one
///                 for what it is, a "Start automatically" switch, Start /
///                 Stop / Restart and its log. Services the session needs
///                 ask before they're stopped or switched off. Temporary
///                 services apps start are hidden unless asked for.
/// Which row is open, the pending "are you sure?" and the shown log live
/// here: the rows are rebuilt each time the list refreshes (every 5 s).
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var userServices: []
    property var systemServices: []
    property string message: ""
    property bool messageIsError: false
    property string query: ""
    property bool onlyProblems: false
    property bool showTemporary: false
    /// Per list: are the core services (the session needs them) shown?
    property var showCore: ({ user: false, system: false })
    /// Which lists are open (the cards are rebuilt on every refresh).
    property var openLists: ({ user: true, system: false })
    property string expandedKey: ""
    /// { key, op } waiting for "are you sure?", or null.
    property var confirm: null
    property string logKey: ""
    property string logText: ""

    // New-service form.
    property bool formOpen: false
    property string formScope: "user"
    property bool customArgs: false
    property bool startNow: true
    property string programPath: ""
    property bool programChecked: false

    /// Only your own actions make the page busy; the background refresh
    /// runs separately, so a click never lands on a disabled button.
    readonly property bool busy: worker.running
    /// Counts finished actions, so a refresh that started before one ended
    /// can't show the state from before it.
    property int actionsDone: 0
    property int refreshFrom: 0
    function refresh() {
        const from = actionsDone;
        if (lister.run("list")) refreshFrom = from;
    }
    readonly property var failedServices: userServices.concat(systemServices).filter(s => s.state === "failed")

    function keyOf(scope, service) { return scope + ":" + service.unit; }
    function matches(s) {
        const q = query.trim().toLowerCase();
        return q === "" || s.name.toLowerCase().includes(q) || s.unit.toLowerCase().includes(q)
            || (s.about ?? "").toLowerCase().includes(q);
    }
    /// Failed first, then running, then the rest; each by name.
    function rank(s) { return s.state === "failed" ? 0 : s.running ? 1 : 2; }
    function byRank(a, b) { return rank(a) - rank(b) || a.name.localeCompare(b.name); }
    /// Core services stay tucked away unless shown, searched for, or failed.
    function isTucked(s) { return s.essential && s.state !== "failed" && query.trim() === ""; }
    function shown(list, scope) {
        return list.filter(s => matches(s) && (!onlyProblems || s.state === "failed")
                                && (scope !== "user" || showTemporary || !s.transient))
            .sort(byRank);
    }

    function run(operation, args = []) {
        if (worker.run(operation, args)) { message = ""; messageIsError = false; }
    }

    /// A row's button or switch. Services the session needs ask first.
    function handle(scope, service, operation) {
        const key = keyOf(scope, service);
        const args = [scope, service.unit];
        switch (operation) {
        case "stop":
        case "disable":
            if (service.essential) { confirm = { key: key, op: operation }; return; }
            run(operation, args);
            return;
        case "confirm":
            if (confirm?.key === key) run(confirm.op, args);
            confirm = null;
            return;
        case "cancel":
            confirm = null;
            return;
        case "log":
            logKey = key;
            logText = "";
            run("log", args);
            return;
        case "hidelog":
            logKey = "";
            logText = "";
            return;
        default:
            run(operation, args);
        }
    }

    /// systemctl/pkexec wording → something a newcomer can act on.
    function friendlyError(text) {
        if (/not authori[sz]ed|authentication|cancel|dismissed|Access denied/i.test(text))
            return "Nothing changed: the password prompt was cancelled.";
        return "That didn't work: " + text;
    }

    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: root.pageShown; onTriggered: root.refresh() }

    Lib.JsonScript {
        id: lister
        script: "system/services.py"
        fallbackError: "Could not read the services."
        onFailed: message => { root.message = message; root.messageIsError = true; }
        onSucceeded: result => {
            if (root.refreshFrom !== root.actionsDone) return;  // older than the last action
            root.userServices = result.user ?? [];
            root.systemServices = result.system ?? [];
        }
    }

    Lib.JsonScript {
        id: worker
        script: "system/services.py"
        fallbackError: "Could not read or change the services."
        onFailed: message => { root.message = root.friendlyError(message); root.messageIsError = true; }
        onSucceeded: (result, operation) => {
            if (operation === "log") { root.logText = result.log ?? ""; return; }
            root.actionsDone++;
            root.userServices = result.user ?? [];
            root.systemServices = result.system ?? [];
            if (operation === "create") {
                programField.text = "";
                argsField.text = "";
                root.programPath = "";
                root.programChecked = false;
                root.formOpen = false;
            }
            if (operation !== "list") root.message = ({
                create: "Created. It's in the list below.", start: "Started.", stop: "Stopped.",
                restart: "Restarted.", remove: "Removed.",
                enable: "It will start automatically from now on.", disable: "It won't start automatically any more."
            })[operation] ?? "";
        }
    }

    // Checks the program name as it's typed (debounced).
    Lib.JsonScript {
        id: probe
        script: "system/services.py"
        onSucceeded: result => { root.programPath = result.which ?? ""; root.programChecked = true; }
    }
    Timer {
        id: probeDelay
        interval: 300
        onTriggered: {
            const name = programField.text.trim();
            if (name === "") { root.programPath = ""; root.programChecked = false; return; }
            if (!probe.run("which", [name])) restart();
        }
    }

    // ─── About ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Background services"
        description: "Services are programs that run without a window: sound, Wi-Fi, file syncing, the login "
            + "screen. Your services run as you while you're logged in; system services run for the whole "
            + "computer and need your password to change. Click a service to see what it does."

        Rectangle {
            width: parent.width
            visible: root.failedServices.length > 0
            implicitHeight: problemRow.implicitHeight + 16
            radius: Services.Ui.radiusSm
            color: "transparent"
            border.color: Services.Colors.red
            border.width: 1
            Row {
                id: problemRow
                x: 10
                y: 8
                width: parent.width - 20
                spacing: 12
                Components.StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - problemButton.width - 12
                    text: (root.failedServices.length === 1 ? "1 service has" : root.failedServices.length + " services have")
                        + " stopped with an error: " + root.failedServices.map(s => s.name).join(", ")
                    color: Services.Colors.red
                    wrapMode: Text.WordWrap
                    font.pixelSize: Services.Ui.textSmall
                }
                Components.TextButton {
                    id: problemButton
                    text: root.onlyProblems ? "Show all" : "Show"
                    buttonHeight: 28
                    onClicked: {
                        root.onlyProblems = !root.onlyProblems;
                        if (root.onlyProblems) root.openLists = { user: true, system: true };
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            Components.SettingField {
                width: parent.width - addButton.width - 10
                placeholder: "Search services, e.g. sound, wifi, bluetooth"
                onLiveEdited: value => root.query = value
            }
            Components.TextButton {
                id: addButton
                text: root.formOpen ? "Close" : "+ Add a service"
                onClicked: root.formOpen = !root.formOpen
            }
        }

        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: root.message
            wrapMode: Text.WordWrap
            color: root.messageIsError ? Services.Colors.red : Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
        }
    }

    // ─── Add a service ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: root.formOpen
        title: "Add a service"
        description: "Keeps a program running in the background, starts it automatically, and restarts it if it crashes."

        Components.LabeledSettingRow {
            width: parent.width
            label: "Program"
            labelWidth: 120
            Components.SettingField {
                id: programField
                width: parent.width
                placeholder: "The command you'd type in a terminal, e.g. syncthing"
                onLiveEdited: { root.programChecked = false; probeDelay.restart(); }
            }
        }
        Components.StyledText {
            x: 120
            width: parent.width - 120
            visible: programField.text.trim() !== ""
            text: !root.programChecked ? "Checking…"
                : root.programPath ? "✓ Found " + root.programPath
                : "✗ There's no program called \"" + programField.text.trim() + "\". Check the spelling, or install it first."
            color: !root.programChecked ? Services.Colors.surfaceVariantText
                : root.programPath ? Services.Colors.green : Services.Colors.red
            wrapMode: Text.WordWrap
            font.pixelSize: Services.Ui.textCaption
        }

        Components.SegmentedControl {
            label: "Run it for"
            labelWidth: 120
            model: [{ value: "user", label: "Just me" }, { value: "system", label: "Everyone (as administrator)" }]
            valueRole: "value"; textRole: "label"
            currentValue: root.formScope
            onSelected: value => root.formScope = value
        }
        Components.StyledText {
            width: parent.width
            text: root.formScope === "user"
                ? "Runs as you, from when you log in until you log out. Right for most apps."
                : "Runs as the administrator (root) from when the computer starts, even before anyone logs in. "
                  + "Only for programs that need it; creating it asks for your password."
            color: root.formScope === "user" ? Services.Colors.surfaceVariantText : Services.Colors.yellow
            wrapMode: Text.WordWrap
            font.pixelSize: Services.Ui.textCaption
        }

        Components.SettingsToggle {
            width: parent.width
            label: "Add options"
            description: "Extra things to pass to the program, as you'd type them after its name."
            checked: root.customArgs
            onToggled: value => root.customArgs = value
        }
        Components.LabeledSettingRow {
            width: parent.width
            visible: root.customArgs
            label: "Options"
            labelWidth: 120
            Components.SettingField {
                id: argsField
                width: parent.width
                placeholder: "e.g. --no-browser"
            }
        }
        Components.SettingsToggle {
            width: parent.width
            label: "Start it now"
            description: "Otherwise it first starts " + (root.formScope === "user" ? "the next time you log in." : "the next time the computer starts.")
            checked: root.startNow
            onToggled: value => root.startNow = value
        }

        Components.StyledText {
            width: parent.width
            visible: root.programPath !== ""
            text: "It will run  " + root.programPath + (root.customArgs && argsField.text.trim() ? " " + argsField.text.trim() : "")
                + "  " + (root.formScope === "user" ? "whenever you log in" : "whenever the computer starts")
                + (root.startNow ? ", starting now" : "") + "."
            wrapMode: Text.WordWrap
            font.pixelSize: Services.Ui.textSmall
        }
        Row {
            spacing: 10
            Components.TextButton {
                text: "Create"
                fontBold: true
                enabled: !root.busy && root.programPath !== ""
                onClicked: root.run("create", [root.formScope, programField.text.trim(), root.startNow ? "1" : "0",
                    root.customArgs ? argsField.text : ""])
            }
            Components.TextButton {
                text: "Cancel"
                onClicked: root.formOpen = false
            }
        }
    }

    // ─── The lists ───
    Repeater {
        model: [
            { scope: "user", title: "Your services", list: root.userServices },
            { scope: "system", title: "System services", list: root.systemServices }
        ]

        Components.Card {
            id: group
            required property var modelData
            readonly property var all: root.shown(modelData.list, modelData.scope)
            readonly property var core: all.filter(root.isTucked)
            readonly property var rows: root.showCore[modelData.scope] ? all : all.filter(s => !root.isTucked(s))
            readonly property int temporary: modelData.list.filter(s => s.transient).length
            x: root.horizontalPadding
            width: root.rowWidth
            title: modelData.title + "  ·  " + all.filter(s => s.running).length + " running"
                + (all.length > all.filter(s => s.running).length ? ", " + (all.length - all.filter(s => s.running).length) + " not running" : "")
            collapsible: true
            // A search or "Show problems" opens both, so matches are never hidden.
            expanded: root.openLists[modelData.scope] || root.query.trim() !== ""
            onToggled: value => {
                root.openLists = Object.assign({}, root.openLists, { [modelData.scope]: value });
                // The card's own click replaced the binding above; put it back.
                expanded = Qt.binding(() => root.openLists[modelData.scope] || root.query.trim() !== "");
            }

            Components.StyledText {
                visible: group.rows.length === 0
                text: root.query || root.onlyProblems ? "Nothing matches." : "Only core services here."
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
            }
            Column {
                width: parent.width
                spacing: 2
                Repeater {
                    model: group.rows
                    SettingsUi.ServiceRow {
                        required property var modelData
                        readonly property string key: root.keyOf(group.modelData.scope, modelData)
                        service: modelData
                        scope: group.modelData.scope
                        busy: root.busy
                        expanded: root.expandedKey === key
                        confirming: root.confirm?.key === key ? root.confirm.op : ""
                        logText: root.logKey === key ? (root.logText || "Loading…") : ""
                        onToggleExpanded: {
                            root.expandedKey = expanded ? "" : key;
                            root.confirm = null;
                        }
                        onAction: operation => root.handle(group.modelData.scope, modelData, operation)
                    }
                }
            }
            Components.StyledText {
                width: parent.width
                visible: group.core.length > 0 && !root.onlyProblems
                text: (root.showCore[group.modelData.scope] ? "Hide the " : "Show ") + group.core.length
                    + " core service" + (group.core.length === 1 ? "" : "s")
                    + (root.showCore[group.modelData.scope] ? "" : " your " + (group.modelData.scope === "user" ? "session" : "computer")
                       + " needs (sound, network, login…). Best left alone.")
                color: Services.Colors.accent
                wrapMode: Text.WordWrap
                font.pixelSize: Services.Ui.textSmall
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showCore = Object.assign({}, root.showCore,
                        { [group.modelData.scope]: !root.showCore[group.modelData.scope] })
                }
            }
            Components.StyledText {
                visible: group.modelData.scope === "user" && group.temporary > 0 && !root.onlyProblems
                text: (root.showTemporary ? "Hide" : "Show") + " " + group.temporary
                    + " temporary service" + (group.temporary === 1 ? "" : "s") + " started by apps"
                color: Services.Colors.accent
                font.pixelSize: Services.Ui.textSmall
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showTemporary = !root.showTemporary
                }
            }
        }
    }
}
