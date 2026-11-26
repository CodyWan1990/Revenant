import QtQuick
import "../services" as Services
import "../components" as Components

/// polkit's admin password prompt (pkexec, mounts, system settings), drawn by
/// the shell when it is the session's agent (services/Polkit.qml).
///
/// `flow` is the current Quickshell AuthFlow, or null. The panel opens when a
/// request arrives and closes when polkit finishes it. Closing it any other
/// way (Esc, Cancel, another panel taking over) cancels the request, so a
/// caller like pkexec never waits on a prompt nobody can see. It does not
/// close on focus loss: a stray click must not cancel an admin prompt.
Components.OverlayPanel {
    id: panel

    required property var flow
    closeOnFocusLoss: false

    readonly property var identities: flow?.identities ?? []
    readonly property bool canRespond: !!flow && flow.isResponseRequired && !flow.isCompleted

    /// Identity has no QML type info. Seen live: { id: 1000, string: "<user name>",
    /// displayName: "Full Name", isGroup: false } (a group is "group:<name>").
    function identityName(identity) {
        return identity?.displayName || identity?.string || "";
    }

    function submit() {
        if (!canRespond) return;
        flow.submit(field.text);
        field.clear();
    }

    onFlowChanged: {
        if (flow) open();
        else if (isOpen) close();
    }
    onOpened: field.clear()
    onFocusRequested: field.takeFocus()
    onIsOpenChanged: {
        field.clear();   // never keep a typed password around
        if (!isOpen && flow && !flow.isCompleted) flow.cancelAuthenticationRequest();
    }

    Connections {
        target: panel.flow
        function onIsCompletedChanged() { if (panel.flow?.isCompleted) panel.close(); }
        function onIsResponseRequiredChanged() { if (panel.canRespond) field.takeFocus(); }
    }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: 460
        height: body.implicitHeight + 40
        opacity: panel.contentOpacity

        Column {
            id: body
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Components.StyledText {
                width: parent.width
                text: String.fromCodePoint(0xF033E) + "  Authentication required"   // nf-md-lock
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSubtitleLarge
                font.bold: true
            }

            Components.StyledText {
                width: parent.width
                text: panel.flow?.message ?? ""
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBodyLarge
                wrapMode: Text.WordWrap
            }

            Components.StyledDropdown {
                width: parent.width
                visible: panel.identities.length > 1
                label: "As"
                labelWidth: 40
                model: panel.identities.map(identity => panel.identityName(identity))
                currentValue: panel.identityName(panel.flow?.selectedIdentity)
                onSelected: name => {
                    const identity = panel.identities.find(item => panel.identityName(item) === name);
                    if (identity && panel.flow) panel.flow.selectedIdentity = identity;
                }
            }

            Components.PasswordField {
                id: field
                objectName: "polkitPassword"   // tests/polkitpanel.qml types into it
                width: parent.width
                enabled: panel.canRespond
                placeholder: (panel.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                alwaysVisible: panel.flow?.responseVisible ?? false
                onAccepted: panel.submit()
                onCancelled: panel.close()
            }

            // Always takes its line, even when empty: the window is sized when
            // it opens and doesn't grow under i3, so a message appearing later
            // (after a wrong password) would push the content out of view.
            Components.StyledText {
                width: parent.width
                height: 16
                text: panel.flow?.supplementaryMessage
                    || (panel.flow?.failed ? "Password invalid. Please try again." : "")
                color: (panel.flow?.supplementaryIsError || panel.flow?.failed)
                    ? Services.Colors.red : Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
                elide: Text.ElideRight
            }

            Row {
                spacing: 8
                Components.TextButton {
                    text: "Authenticate"
                    fontBold: true
                    enabled: panel.canRespond && field.text.length > 0
                    onClicked: panel.submit()
                }
                Components.TextButton {
                    text: "Cancel"
                    onClicked: panel.close()
                }
            }

            Components.StyledText {
                width: parent.width
                text: (panel.flow?.actionId ?? "") + "  ·  Enter authenticate · Esc cancel"
                    + (field.alwaysVisible ? "" : " · Ctrl+H " + (field.reveal ? "hide" : "show"))
                color: Services.Colors.color8
                font.pixelSize: Services.Ui.textCaption
                elide: Text.ElideMiddle
            }
        }
    }
}
