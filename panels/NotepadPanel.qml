import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services" as Services
import "../components" as Components

/// Scratch notepad, modelled on Dux Shell's Notepad (MIT). One plain-text note
/// in ~/.local/state/<shell>/notepad.md, saved 0.6 s after you stop typing,
/// on Ctrl+S, and on close. Esc closes.
Components.OverlayPanel {
    id: panel

    readonly property string notePath: Services.Paths.notepadPath
    property bool dirty: false
    property bool loaded: false
    property string saveError: ""

    function save() {
        if (!dirty) return;
        // Clear before writing: typing during the write marks it dirty again,
        // and a failed write puts it back (onSaveFailed), so nothing is lost
        // by thinking it was saved.
        dirty = false;
        file.setText(editor.text);
    }

    onOpened: { if (!loaded) file.reload(); }
    onFocusRequested: editor.forceActiveFocus()
    onIsOpenChanged: if (!isOpen) save()

    FileView {
        id: file
        path: "file://" + panel.notePath
        preload: true
        printErrors: false          // no note yet is normal
        // A missing file is fine: the first save creates it (Paths creates
        // the state dir at start).
        onLoaded: {
            if (!panel.dirty) editor.text = this.text();
            panel.loaded = true;
        }
        onLoadFailed: panel.loaded = true
        onSaved: panel.saveError = ""
        onSaveFailed: error => {
            panel.dirty = true;
            panel.saveError = "Not saved: " + error;
            console.warn("Notepad: save failed:", error);
        }
    }

    Timer { id: autosave; interval: 600; onTriggered: panel.save() }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: 760
        height: 560
        opacity: panel.contentOpacity

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Components.StyledText {
                    text: "Notepad"
                    color: Services.Colors.foreground
                    font.pixelSize: Services.Ui.textHeading
                    font.bold: true
                    Layout.fillWidth: true
                }
                Components.StyledText {
                    text: panel.saveError || (panel.dirty ? "Editing…" : "Saved")
                    color: panel.saveError ? Services.Colors.red : Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textSmall
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Services.Colors.surfaceContainer

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 14
                    contentWidth: width
                    contentHeight: editor.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    function ensureVisible(r) {
                        if (contentY >= r.y) contentY = r.y;
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
                    }

                    TextEdit {
                        id: editor
                        width: flick.width
                        height: Math.max(flick.height, contentHeight)
                        wrapMode: TextEdit.Wrap
                        color: Services.Colors.foreground
                        selectionColor: Services.Colors.primaryContainer
                        selectedTextColor: Services.Colors.primaryContainerText
                        font.family: Services.Settings.fontFamily
                        font.pixelSize: Services.Ui.textSubtitle
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        onTextChanged: if (panel.loaded) { panel.dirty = true; autosave.restart(); }

                        Keys.onEscapePressed: panel.close()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                                panel.save();
                                event.accepted = true;
                            }
                        }
                    }

                    Components.StyledText {
                        visible: editor.text === ""
                        text: "Jot something down…"
                        color: Services.Colors.color8
                        font.pixelSize: Services.Ui.textSubtitle
                    }
                }
            }

            Components.StyledText {
                text: "Saved to " + panel.notePath.replace(/^\/home\/[^/]+/, "~") + " · Ctrl+S save · Esc close"
                color: Services.Colors.color8
                font.pixelSize: Services.Ui.textSmall
            }
        }
    }
}
