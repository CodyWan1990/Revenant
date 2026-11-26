import QtQuick
import Quickshell
import "../services" as Services

/// Shared chrome for the keyboard-driven panels (launcher, clipboard, power,
/// window switcher, screenshot): toggle/open/close, a delayed focus signal and
/// a content fade.
///
/// On X11 this is a FloatingWindow, the only Quickshell window i3 gives
/// keyboard focus to (spike-tested: PanelWindows become docks, PopupWindows are
/// override-redirect and never get keys). Quickshell sets no WM_CLASS, so i3
/// matches the title instead. i3/revenant.config (shipped here) floats it
/// borderless and centres it on the focused output each time it maps.
///
/// The window is sized to the panel's OverlaySurface child (the first child
/// with `isOverlaySurface`, searched two levels deep), so give that surface a fixed width/height.
/// Clicking another window = the panel loses focus = close (see "Focus loss").
FloatingWindow {
    id: panel

    property int focusDelayMs: 60
    property bool closeOnFocusLoss: true
    /// Logical open state — true from open() until close(); visible stays true
    /// slightly longer so the fade-out can play.
    property bool isOpen: false
    /// Bind content root opacity to this.
    property real contentOpacity: 0

    signal opened()
    signal focusRequested()

    // i3 matches panels by title (no WM_CLASS): the shell's name, see
    // i3/revenant.config.
    title: Services.Paths.shellName
    color: Services.Colors.background
    visible: false

    // Direct child, or one level down: PowerMenu wraps its surface in a
    // FocusScope that fills the window (so keys reach it).
    readonly property Item surface: {
        for (let c of panel.contentItem.children) {
            if (c.isOverlaySurface === true) return c;
            for (let g of c.children)
                if (g.isOverlaySurface === true) return g;
        }
        return null;
    }
    implicitWidth: surface ? surface.width : 600
    implicitHeight: surface ? surface.height : 400

    // ─── Fit the window to its content while open ───
    // i3 keeps a floating window's size once it is mapped and ignores the
    // window's own resize requests, so a panel whose content grows while open
    // (an error line, a message that wraps after the first layout) would be
    // clipped. Ask i3 directly instead, and re-centre. Panels are the only
    // mapped windows titled with the shell's name, and only one is open at a time.
    onImplicitWidthChanged: if (isOpen) fitDelay.restart()
    onImplicitHeightChanged: if (isOpen) fitDelay.restart()
    Timer {
        id: fitDelay
        interval: 30   // batch a burst of layout changes into one command
        onTriggered: if (panel.isOpen && panel.visible)
            Services.I3.run("[title=\"^" + Services.Paths.shellName + "$\"] resize set " + Math.round(panel.implicitWidth)
                + " px " + Math.round(panel.implicitHeight) + " px, move position center")
    }

    Behavior on contentOpacity {
        NumberAnimation {
            duration: panel.isOpen ? Services.Ui.durOpen : Services.Ui.durClose
            easing.type: Easing.OutCubic
        }
    }

    function toggle() { if (isOpen) close(); else open(); }

    function open() {
        // One panel at a time, and no dropdown left hanging under it.
        if (Services.Ui.exclusivePanel && Services.Ui.exclusivePanel !== panel)
            Services.Ui.exclusivePanel.close();
        Services.Ui.exclusivePanel = panel;
        if (Services.Ui.openPopup) Services.Ui.openPopup.close();

        isOpen = true;
        hadFocus = false;
        opened();
        visible = true;
        contentOpacity = 1;
        focusDelay.start();
        fitDelay.restart();   // the first layout can settle after the map
    }

    function close() {
        if (Services.Ui.exclusivePanel === panel)
            Services.Ui.exclusivePanel = null;
        isOpen = false;
        contentOpacity = 0;
        hideDelay.restart();
    }

    Timer { id: focusDelay; interval: panel.focusDelayMs; onTriggered: panel.focusRequested() }

    // Unmap after the fade-out; a reopen mid-fade leaves isOpen true so this no-ops.
    Timer {
        id: hideDelay
        interval: Services.Ui.durClose
        onTriggered: if (!panel.isOpen) panel.visible = false
    }

    // ─── Focus loss = clicked elsewhere ───
    // i3 runs with `focus_follows_mouse no`, so the panel only loses focus
    // when you click another window (or switch workspace by key). Close then.
    // hadFocus: ignore the "inactive" state before i3 first focuses the map.
    property bool hadFocus: false

    Item {
        Window.onActiveChanged: {
            if (Window.active) panel.hadFocus = true;
            else if (panel.isOpen && panel.hadFocus && panel.closeOnFocusLoss) panel.close();
        }
    }
}
