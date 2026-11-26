import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../lib/BarStyle.js" as BarStyle

/// Dropdown for bar widgets — an X11 PopupWindow anchored under its widget.
///
/// X11 facts this is built around (spike-tested on i3, Quickshell 0.3):
/// - a PopupWindow is override-redirect: i3 never manages it, so it lands
///   exactly under the widget — but it never gets keyboard input. Dropdowns
///   are mouse-only (no Escape).
/// - X11 gives such a window no "clicked outside" signal, and Quickshell's
///   `grabFocus` only grabs on Wayland. So while open, scripts/system/click-watch.py
///   reports every button press on the display (XInput2 raw events, which
///   don't consume the click) and a press outside the popup closes it.
/// - the window is opaque and sized to the content; the fade is an item
///   opacity over the popup's own background colour.
PopupWindow {
    id: popup

    required property var bar
    /// Optional tag so services can tell which dropdown is open (e.g. "audio").
    property string popupKind: ""
    /// The widget to drop down from; null pins the popup to the bar's right edge.
    required property Item parentWidget

    property int contentWidth: 320
    property color accentColor: Services.Colors.color1
    property int contentHeight: -1  // -1 = auto from children
    property int contentMargins: 16

    readonly property var widgetInstance: instanceOf(parentWidget)
    // `widget: var`: bar widget roots are duck-typed; `instance` is theirs.
    function instanceOf(widget: var): var { return widget?.instance ?? null; }
    readonly property string surfaceOverride: widgetInstance?.surface ?? "inherit"
    readonly property var barProfile: bar?.profile ?? Services.Settings.sharedBar
    readonly property bool bottomBar: barProfile.position === "bottom"
    readonly property string surface: BarStyle.effectiveSurface(barProfile.widgetStyle, surfaceOverride)
    readonly property bool segmented: surface === "pill" && surfaceOverride === "inherit"
        && barProfile.widgetStyle === "segments"
    readonly property color widgetAccent: Services.Colors.byKey(widgetInstance?.color, accentColor)

    property int fadeInDuration: Services.Ui.durOpen
    property int fadeOutDuration: Services.Ui.durClose
    property bool useOpenDelay: false

    property bool alignLeft: false
    property int xOffset: 0
    property int xClamp: 8

    property bool isOpen: false
    signal opening()

    default property alias contentData: innerContent.data

    anchor.window: bar
    anchor.rect.y: popup.bottomBar ? -popup.implicitHeight : (bar?.implicitHeight ?? 0)
    implicitWidth: contentWidth
    implicitHeight: popup.contentHeight >= 0
        ? popup.contentHeight
        : innerContent.childrenRect.height + popup.contentMargins * 2
    color: Services.Ui.panelColor
    visible: false

    // ─── Outside click ───
    property double dismissedAt: 0

    Process {
        running: popup.isOpen
        command: ["python3", Services.Paths.script("system/click-watch.py")]
        stdout: SplitParser { onRead: line => popup.pressAt(line) }
    }

    /// `line` is "X Y" in root (virtual screen) coordinates.
    function pressAt(line) {
        if (!isOpen || !bar || !bar.screen) return;
        const p = line.trim().split(/\s+/).map(Number);
        // Translate from the bar window to the X11 root window.
        const left = bar.screen.x + anchor.rect.x;  // qmllint disable unresolved-type
        const top = bar.screen.y + anchor.rect.y  // qmllint disable unresolved-type
            + (bottomBar ? bar.screen.height - bar.implicitHeight : 0);
        if (p[0] >= left && p[0] < left + width && p[1] >= top && p[1] < top + height)
            return;
        dismissedAt = Date.now();
        close();
    }

    // Any bar-layout edit resets TopBar's Repeaters, so a widget can be destroyed
    // out from under its own popup.
    Component.onDestruction: popup.visible = false

    NumberAnimation {
        id: fadeIn
        target: contentRect; property: "opacity"
        from: 0.0; to: 1.0; duration: popup.fadeInDuration
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: fadeOut
        target: contentRect; property: "opacity"
        from: 1.0; to: 0.0; duration: popup.fadeOutDuration
        easing.type: Easing.InCubic
        // Guard: a reopen during the fade-out must not blank the popup when it lands.
        onFinished: if (!popup.isOpen) popup.visible = false
    }

    Timer {
        id: openDelay
        interval: 60
        onTriggered: fadeIn.start()
    }

    function open() {
        if (!bar) return;
        // A press on our own widget closes us (outside the popup), then its
        // click handler toggles: that must not reopen us.
        if (Date.now() - dismissedAt < 300) return;
        // A dropdown and a keyboard panel never stack.
        if (Services.Ui.exclusivePanel) Services.Ui.exclusivePanel.close();
        // One dropdown at a time (a keyboard-opened one, e.g. weather, has no click to dismiss the last).
        if (Services.Ui.openPopup && Services.Ui.openPopup !== popup)
            Services.Ui.openPopup.close();
        Services.Ui.openPopup = popup;

        let x;
        if (!parentWidget) {
            x = (bar.width ?? 0) - contentWidth - xClamp;
        } else {
            let pos = parentWidget.mapToItem(null, 0, 0);
            x = alignLeft
                ? pos.x + xOffset
                : pos.x - contentWidth / 2 + parentWidget.width / 2 + xOffset;
        }
        let maxX = (bar.width ?? 0) - contentWidth - xClamp;
        anchor.rect.x = Math.round(Math.max(xClamp, Math.min(x, maxX)));  // qmllint disable unresolved-type

        contentRect.opacity = 0;
        visible = true;
        isOpen = true;
        opening();
        if (useOpenDelay) openDelay.start();
        else fadeIn.start();
    }

    function close() {
        if (!isOpen) return;
        if (Services.Ui.openPopup === popup) Services.Ui.openPopup = null;
        isOpen = false;
        fadeOut.start();
    }

    // A workspace switch by key moves i3 focus without any click.
    Connections {
        target: Services.I3
        enabled: popup.isOpen
        function onFocusMoved() { popup.close(); }
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        color: popup.parentWidget && popup.surface === "pill"
            ? (popup.bar?.widgetSurfaceColor ?? Services.Colors.widgetSurface) : Services.Ui.panelColor
        radius: !popup.parentWidget ? Services.Ui.radiusLg
            : popup.surface === "pill" && !popup.segmented ? popup.barProfile.pillRadius : Services.Ui.radiusMd
        border.color: !popup.parentWidget && !Services.Ui.accentFrame ? Services.Colors.outlineVariant
            : !popup.parentWidget || popup.surface === "polybar" ? popup.widgetAccent : Services.Colors.outlineVariant
        border.width: !popup.parentWidget ? Services.Ui.frameWidth
            : popup.surface === "polybar" ? 2 : Services.Ui.surfaceStyle === "flat" ? 0 : 1
        opacity: 0

        // The accent edge on the bar side. Placed with `y`, not by switching
        // anchors.top / anchors.bottom: moving the bar to the bottom and back
        // briefly set both, stretching this 2px strip over the popup, and the
        // constant `height: 2` never re-applied once the anchor was cleared.
        Rectangle {
            visible: popup.parentWidget !== null && popup.segmented
            width: parent.width
            height: 2
            y: popup.bottomBar ? parent.height - height : 0
            color: popup.widgetAccent
        }

        Item {
            id: innerContent
            anchors.fill: parent
            anchors.margins: popup.contentMargins
        }
    }
}
