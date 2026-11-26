import QtQuick
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib
import "../../../services" as Services

SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24

    property var themes: ({})
    property var current: ({})
    property string message: ""

    onPageShownChanged: if (pageShown) appearance.run("list")
    Component.onCompleted: if (pageShown) appearance.run("list")

    Lib.JsonScript {
        id: appearance
        script: "theming/desktop-appearance.py"
        fallbackError: "Could not read or apply desktop appearance."
        onFailed: message => root.message = message
        onSucceeded: result => {
            root.themes = result.themes;
            root.current = result.current;
            root.message = result.warnings.join(" ");
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Desktop icons & cursor"
        description: "Choose from installed themes. Some apps pick up changes when reopened."

        Repeater {
            model: [
                { kind: "icons", label: "Icon theme" },
                { kind: "cursors", label: "Cursor theme" }
            ]

            delegate: Components.StyledDropdown {
                required property var modelData
                label: modelData.label
                labelWidth: 120
                model: root.themes[modelData.kind] ?? []
                currentValue: root.current[modelData.kind] ?? ""
                placeholder: appearance.running ? "Checking…" : (model.length ? "System default" : "No themes found")
                filterable: true
                enabled: !appearance.running && model.length > 0
                onSelected: value => {
                    if (value !== currentValue)
                        appearance.run("set", [modelData.kind, value]);
                }
            }
        }

        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: root.message
            color: Services.Colors.red
            wrapMode: Text.WordWrap
        }
    }
}
