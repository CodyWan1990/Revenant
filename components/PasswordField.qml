import QtQuick
import "../services" as Services

/// Password input with a show/hide eye (also Ctrl+H) and a placeholder.
/// Shared by the Wi-Fi and admin (polkit) prompts. `reveal` shows the text;
/// set `alwaysVisible` for prompts that ask for something not secret.
Rectangle {
    id: root

    property alias text: field.text
    property string placeholder: "Password"
    property bool reveal: false
    /// The prompt's input isn't secret (polkit can ask that): no mask, no eye.
    property bool alwaysVisible: false
    readonly property bool shown: alwaysVisible || reveal

    signal accepted()
    signal cancelled()

    function takeFocus() { field.forceActiveFocus(); }
    function clear() { field.text = ""; reveal = false; }

    width: parent ? parent.width : 300
    height: 40
    color: Services.Colors.color0
    border.color: field.activeFocus ? Services.Colors.accent : Services.Colors.color8
    border.width: 1

    TextInput {
        id: field
        anchors.left: parent.left
        anchors.right: eye.visible ? eye.left : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.shown ? TextInput.Normal : TextInput.Password
        // Explicit: Qt's default mask is "●", which the UI font lacks
        // (it rendered as nothing).
        passwordCharacter: "*"
        color: Services.Colors.foreground
        font.family: Services.Settings.fontFamily
        font.pixelSize: Services.Ui.textSubtitle
        clip: true

        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onEscapePressed: root.cancelled()
        Keys.onPressed: event => {
            if (!root.alwaysVisible && event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
                root.reveal = !root.reveal;
                event.accepted = true;
            }
        }
    }

    // Eye button: show / hide the password (same as Ctrl+H).
    Item {
        id: eye
        visible: !root.alwaysVisible
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 40

        StyledText {
            anchors.centerIn: parent
            // nf-md-eye / nf-md-eye_off
            text: String.fromCodePoint(root.reveal ? 0xF0209 : 0xF0208)
            color: eyeArea.containsMouse || root.reveal ? Services.Colors.accent : Services.Colors.color8
            font.pixelSize: Services.Ui.px(18)
        }

        MouseArea {
            id: eyeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.reveal = !root.reveal;
                field.forceActiveFocus();   // keep typing where you were
            }
        }
    }

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text.length === 0
        text: root.placeholder
        color: Services.Colors.color8
        font.pixelSize: Services.Ui.textSubtitle
    }
}
