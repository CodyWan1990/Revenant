import QtQuick
import "../../services" as Services
import ".." as Components

/// Filterable dropdown of installed apps (Services.Apps.pickable), shared by
/// Settings → Keybinds and Settings → Autostart. `picked` hands over the app
/// ({ name, id, title }); `currentValue` is the shown title.
Components.StyledDropdown {
    id: root
    label: "App"
    filterable: true
    model: Services.Apps.pickable.map(app => app.title)

    signal picked(var app)

    onSelected: title => {
        const app = Services.Apps.pickable.find(item => item.title === title);
        if (app) root.picked(app);
    }
}
