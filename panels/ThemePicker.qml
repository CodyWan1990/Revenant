import QtQuick
import "../services" as Services
import "../components" as Components
import "appearance" as Appearance

Components.OverlayPanel {
    id: picker
    readonly property string fontFamily: Services.Settings.fontFamily

    onOpened: {
        creatingTheme = false;
        themesView.reset();
        Services.Theme.refresh();
        themeSelectedIndex = Math.max(0,
            Services.Theme.themes.findIndex(theme => theme.slug === Services.Theme.currentSlug));
    }
    onFocusRequested: themesView.focusView()

    // ─── Themes state ─── (filtered grid model lives in ThemesView)
    property int themeSelectedIndex: 0

    // ─── Theme creator state ───
    property bool creatingTheme: false
    property string newThemeName: ""
    property var newPalette: ({})
    property int activeSlotIndex: 0
    readonly property var themeSlots: [
        { key: "bg",      label: "Background", def: "#1f2430" },
        { key: "fg",      label: "Foreground", def: "#cbccc6" },
        { key: "comment",   label: "Muted",     def: "#5c6773" },
        { key: "selection", label: "Selection", def: "#34455a" },
        { key: "red",     label: "Red",        def: "#f28779" },
        { key: "green",   label: "Green",      def: "#bae67e" },
        { key: "yellow",  label: "Yellow",     def: "#ffd580" },
        { key: "blue",    label: "Blue",       def: "#73d0ff" },
        { key: "mauve",   label: "Purple",     def: "#d4bfff" },
        { key: "cyan",    label: "Cyan",       def: "#95e6cb" }
    ]

    function openCreateTheme() {
        let pal = {};
        for (let slot of themeSlots) pal[slot.key] = slot.def;
        newPalette = pal;
        newThemeName = "";
        activeSlotIndex = 0;
        creatingTheme = true;
    }

    function activeSlotColor() {
        return newPalette[themeSlots[activeSlotIndex].key] || "#000000";
    }

    function setSlotColor(key, hex) {
        let p = {};
        for (let k in newPalette) p[k] = newPalette[k];
        p[key] = hex;
        newPalette = p;
    }

    function saveNewTheme() {
        if (newThemeName.trim() === "") return;
        Services.Theme.saveTheme(newThemeName, newPalette);
        creatingTheme = false;
    }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: Math.min(940, (Services.I3.focusedScreen?.width ?? 1280) - 32)
        height: Math.min(660, (Services.I3.focusedScreen?.height ?? 900) - Services.Settings.barFor(Services.I3.focusedScreen?.name ?? "").height - 32)
        opacity: picker.contentOpacity

        Appearance.ThemesView {
            id: themesView
            anchors.fill: parent
            picker: picker
        }

        Appearance.ThemeBuilder {
            anchors.fill: parent
            z: 100
            picker: picker
        }
    }
}
