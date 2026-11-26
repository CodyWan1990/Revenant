import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../components" as Components
import "../components/clipboard" as ClipboardUi
import "../lib" as Lib

/// Clipboard panel with three sections behind one search field:
///   Text    clipmenu 7's history (clipmenud), driven by scripts/clipboard/clip-*.sh
///           through a stub launcher, since clipmenu has no list/pick API
///   Images  images copied to the clipboard (services/ClipImages.qml)
///   Emoji   the vendored emoji table; picking copies and types it
/// openSection() is what the binds call (IPC clipboard / clipimages / emoji):
/// it opens on that section, switches to it if the panel is already up on
/// another one, and closes it if it is already showing that section.
Components.OverlayPanel {
    id: picker

    readonly property var sections: [
        { id: "text", title: "Text", icon: "" },
        { id: "images", title: "Images", icon: "" },
        { id: "emoji", title: "Emoji", icon: "" }
    ]
    property string section: "text"
    property int selectedIndex: 0
    readonly property string query: search.text

    property string fontFamily: Services.Settings.fontFamily

    // ─── Data ───
    property var textEntries: []
    property var emojiTable: []
    readonly property var imageEntries: Services.ClipImages.entries

    readonly property var filteredText: Services.Fuzzy.filter(textEntries, query, e => e.text)
    readonly property var filteredImages: Services.Fuzzy.filter(imageEntries, query, e => ago(e.time))
    // Name and tags both feed the match, so "grin" and "#face" work alike.
    readonly property var filteredEmoji: Services.Fuzzy.filter(emojiTable, query, e => e.name + " " + e.tags)

    readonly property var current: section === "images" ? filteredImages
        : section === "emoji" ? filteredEmoji : filteredText
    readonly property var selected:
        selectedIndex >= 0 && selectedIndex < current.length ? current[selectedIndex] : null

    readonly property int emojiCell: 44
    readonly property int imageCellW: 210
    readonly property int imageCellH: 158

    onCurrentChanged: {
        if (selectedIndex >= current.length) selectedIndex = Math.max(0, current.length - 1);
    }
    onQueryChanged: resetSelection()
    onSectionChanged: resetSelection()

    onOpened: {
        search.text = "";
        resetSelection();
        if (section === "text") loadText();
        if (section === "images") Services.ClipImages.refresh();
    }
    onFocusRequested: search.forceActiveFocus()

    function openSection(name) {
        if (isOpen && section === name) { close(); return; }
        if (isOpen) {
            showSection(name);
            search.forceActiveFocus();
            return;
        }
        section = name;
        open();
    }

    function showSection(name) {
        if (section === name) return;
        section = name;
        if (name === "text") loadText();
        if (name === "images") Services.ClipImages.refresh();
    }

    function cycleSection(step) {
        const ids = sections.map(s => s.id);
        showSection(ids[(ids.indexOf(section) + step + ids.length) % ids.length]);
    }

    function resetSelection() {
        selectedIndex = 0;
        textList.positionViewAtBeginning();
        imageGrid.positionViewAtBeginning();
        emojiGrid.positionViewAtBeginning();
    }

    function nav(dir) {
        if (!current.length) return;
        if (section === "text") {
            if (dir === "up") selectedIndex = Math.max(0, selectedIndex - 1);
            else if (dir === "down") selectedIndex = Math.min(current.length - 1, selectedIndex + 1);
            textList.positionViewAtIndex(selectedIndex, ListView.Contain);
            return;
        }
        const view = section === "images" ? imageGrid : emojiGrid;
        const cols = Math.max(1, Math.floor(view.width / view.cellWidth));
        selectedIndex = Services.Ui.gridStep(selectedIndex, current.length, cols, dir);
        view.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function activate() {
        const entry = selected;
        if (!entry) return;
        if (section === "text") {
            Quickshell.execDetached(["sh", Services.Paths.script("clipboard/clip-select.sh"), entry.line]);
        } else if (section === "images") {
            Services.ClipImages.copy(entry);
        } else {
            pickEmoji(entry.char);
        }
        close();
    }

    function removeSelected(idx) {
        const entry = current[idx];
        if (!entry || section === "emoji") return;
        if (section === "images") {
            Services.ClipImages.remove(entry);
            return;
        }
        textDeleteProc.run(["bash", Services.Paths.script("clipboard/clip-delete.sh"), entry.line]);
    }

    function clearSection() {
        if (section === "images") Services.ClipImages.clear();
        else if (section === "text") textWipeProc.running = true;
    }

    function loadText() {
        textListProc.run(["python3", Services.Paths.script("clipboard/clip-entries.py")]);
    }

    // ─── Emoji: copy, then type it into the window that had focus ───
    /// xdotool is optional — probed once so a missing binary degrades to
    /// copy-only rather than leaving the pick silently doing nothing.
    property bool canType: false

    function pickEmoji(ch) {
        // argv positional, never interpolated: the table is data we did not author.
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | xclip -selection clipboard >/dev/null 2>&1', "sh", ch]);
        if (canType) {
            typeProc.command = ["xdotool", "type", "--clearmodifiers", "--", ch];
            typeDelay.restart();
        }
    }

    // close() fades for Ui.durClose before the window unmaps; typing before i3
    // has refocused the previous window would send the keystrokes into this
    // dying panel — the same race the old rofi emoji script covered with `sleep 0.2`.
    Timer {
        id: typeDelay
        interval: Services.Ui.durClose + 60
        onTriggered: typeProc.running = true
    }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: Math.min(720, (Services.I3.focusedScreen?.width ?? 900) - 32)
        height: Math.min(580, (Services.I3.focusedScreen?.height ?? 900)
            - Services.Settings.barFor(Services.I3.focusedScreen?.name ?? "").height - 32)
        opacity: picker.contentOpacity

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ─── Section headers ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Components.SectionTabs {
                    sections: picker.sections
                    current: picker.section
                    iconSize: Services.Ui.textSubtitle
                    titleSize: Services.Ui.textBodyLarge
                    counts: ({ text: picker.textEntries.length, images: picker.imageEntries.length })
                    onSelected: id => {
                        picker.showSection(id);
                        search.forceActiveFocus();
                    }
                }

                Item { Layout.fillWidth: true }

                Components.TextButton {
                    text: "Clear history"
                    visible: picker.section !== "emoji" && picker.current.length > 0
                    enabled: !textWipeProc.running
                    onClicked: picker.clearSection()
                }
            }

            Components.SearchHeader {
                Layout.fillWidth: true
                icon: Services.Icons.markup("clipboard", "auto", Services.Colors.accent)
                iconFormat: Text.RichText
                placeholder: picker.section === "emoji" ? "Search emoji"
                    : picker.section === "images" ? "Search images by time" : "Search clipboard"
                showPlaceholder: search.text.length === 0
                info: picker.section === "emoji" ? picker.current.length + " emoji"
                    : picker.current.length === 1 ? "1 item" : picker.current.length + " items"

                TextInput {
                    id: search
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: Services.Colors.foreground
                    font.family: picker.fontFamily
                    font.pixelSize: Services.Ui.textTitle
                    clip: true

                    Keys.onEscapePressed: picker.close()
                    Keys.onReturnPressed: picker.activate()
                    Keys.onEnterPressed: picker.activate()
                    Keys.onUpPressed: picker.nav("up")
                    Keys.onDownPressed: picker.nav("down")
                    // Left/Right move the text cursor in a list; in a grid they move the selection.
                    Keys.onLeftPressed: e => { if (picker.section === "text") e.accepted = false; else picker.nav("left"); }
                    Keys.onRightPressed: e => { if (picker.section === "text") e.accepted = false; else picker.nav("right"); }
                    Keys.onDeletePressed: e => {
                        if (picker.section === "emoji") e.accepted = false;
                        else picker.removeSelected(picker.selectedIndex);
                    }
                    Keys.onTabPressed: picker.cycleSection(1)
                    Keys.onBacktabPressed: picker.cycleSection(-1)
                    Keys.onPressed: e => {
                        if (!(e.modifiers & Qt.ControlModifier)) return;
                        const i = e.key - Qt.Key_1;
                        if (i >= 0 && i < picker.sections.length) {
                            picker.showSection(picker.sections[i].id);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_PageDown || e.key === Qt.Key_PageUp) {
                            picker.cycleSection(e.key === Qt.Key_PageDown ? 1 : -1);
                            e.accepted = true;
                        }
                    }
                }
            }

            // ─── Section content ───
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Services.Ui.radiusMd
                color: Services.Ui.cardColor
                border.color: Services.Ui.subtleBorder
                border.width: Services.Ui.surfaceStyle === "flat" ? 0 : 1
                clip: true

                Components.StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: picker.current.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: picker.query.trim() ? "Nothing matches"
                        : picker.section === "text" ? (textListProc.busy ? "Loading history…" : "Clipboard history is empty")
                        : picker.section === "images" ? "No images yet. Copy one (a screenshot, an image in the browser) and it shows up here."
                        : "Loading emoji…"
                    color: Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textBodyLarge
                }

                ClipboardUi.ClipTextList {
                    id: textList
                    panel: picker
                }

                ClipboardUi.ClipImageGrid {
                    id: imageGrid
                    panel: picker
                }

                ClipboardUi.EmojiGrid {
                    id: emojiGrid
                    panel: picker
                }

            }

            // ─── About the selection: the whole text clip, scrolling past ~8 lines ───
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(36, Math.min(detail.implicitHeight, 150) + 16)
                visible: !!picker.selected
                radius: Services.Ui.radiusMd
                color: Services.Ui.fieldColor

                Flickable {
                    id: detailScroll
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    contentHeight: detail.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Components.StyledText {
                        id: detail
                        width: detailScroll.width
                        // A short line sits in the middle of the box, like before.
                        y: Math.max(0, (detailScroll.height - implicitHeight) / 2)
                        textFormat: Text.PlainText
                        onTextChanged: detailScroll.contentY = 0
                        text: {
                            const e = picker.selected;
                            if (!e) return "";
                            if (picker.section === "emoji") return e.name + "   " + e.tags;
                            if (picker.section === "images") {
                                const size = sizeProbe.status === Image.Ready
                                    ? sizeProbe.implicitWidth + " × " + sizeProbe.implicitHeight + "  ·  " : "";
                                return size + e.mime.replace("image/", "").toUpperCase() + "  ·  copied " + Services.Fmt.ago(e.time);
                            }
                            return e.text.replace(/\n$/, "");
                        }
                        color: Services.Colors.foreground
                        font.pixelSize: Services.Ui.textBody
                        wrapMode: Text.Wrap
                        Accessible.name: "Selected clipboard entry details"
                    }
                }

                // Reads the full image's size for the line above.
                Image {
                    id: sizeProbe
                    visible: false
                    asynchronous: true
                    source: picker.section === "images" && picker.selected ? "file://" + picker.selected.path : ""
                }
            }

            Components.StyledText {
                Layout.fillWidth: true
                text: (picker.section === "text" ? "↑↓ Select  ·  Enter Copy  ·  Del Remove"
                    : picker.section === "images" ? "Arrows Select  ·  Enter Copy  ·  Del Remove"
                    : "Arrows Select  ·  Enter Insert")
                    + "  ·  Tab / Ctrl+1–3 Section  ·  Esc Close"
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textCaption
                elide: Text.ElideRight
            }
        }
    }

    // ─── Text: load clipmenu history ───
    // Queued (latest wins): a reload asked for mid-load runs once it's done.
    Lib.QueuedProcess {
        id: textListProc
        // [{ line ("[N] label", for clip-select/-delete), display (the label),
        //    text (the whole clip, for the preview), binary }], newest first.
        stdout: StdioCollector {
            onStreamFinished: {
                let entries = [];
                try { entries = JSON.parse(this.text); }
                catch (e) { console.warn("ClipboardPanel: bad clip-entries.py output:", e); }
                // Binary (not valid UTF-8): an image clipmenud stored as text,
                // because xclip answers its UTF8_STRING request with the image
                // bytes. Images live in the Images section instead.
                picker.textEntries = entries.filter(e => e.line && !e.binary);
            }
        }
    }

    // Every delete runs, in order (Del held down repeats); then reload.
    Lib.QueuedProcess {
        id: textDeleteProc
        keepAll: true
        onFinished: picker.loadText()
    }

    Process {
        id: textWipeProc
        // clipmenu 7 deletes inside its store; clipmenud keeps running.
        command: ["clipdel", "-d", ".*"]
        running: false
        // Clear the list only if clipdel worked; otherwise show what's left.
        onExited: code => { if (code === 0) picker.textEntries = []; else picker.loadText(); }  // qmllint disable signal-handler-parameters
    }

    // ─── Emoji table ─── vendored so the shell stays self-contained.
    FileView {
        path: Services.Paths.base + "/assets/emoji.txt"
        onLoaded: {
            const rows = [];
            for (const line of this.text().split("\n")) {
                if (!line) continue;
                // "<char>  <NAME>  #tag #tag" — the char never contains a space,
                // ZWJ sequences use U+200D.
                const parts = line.split("  ");
                if (parts.length < 2) continue;
                rows.push({ char: parts[0], name: parts[1], tags: parts[2] ?? "" });
            }
            picker.emojiTable = rows;
        }
        onLoadFailed: console.warn("ClipboardPanel: could not read assets/emoji.txt")
    }

    Process {
        id: typeProc
        command: ["true"]
        running: false
    }

    Process {
        id: xdotoolProbe
        running: true
        command: ["sh", "-c", "command -v xdotool >/dev/null 2>&1 && echo y || echo n"]
        stdout: StdioCollector {
            onStreamFinished: picker.canType = this.text.trim() === "y"
        }
    }
}
