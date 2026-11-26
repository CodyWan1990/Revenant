pragma Singleton

import QtQuick

/// In-process action bus — bar items and the IpcHandler (driven by i3 keybinds) emit these; shell.qml wires them to panel toggles.
QtObject {
    signal launcher()
    signal clipboard()
    signal clipimages()
    signal windowswitcher()
    signal powermenu()
    signal wallpaper()
    signal themeSettings()
    signal themePicker()
    signal settings()
    signal screenshot()
    signal weather()
    signal emoji()
    signal processes()
    signal keybinds()
    signal notepad()
    /// Ask for a Wi-Fi password (panels/WifiPasswordPanel.qml); `error` is
    /// shown above the field, e.g. after a failed attempt.
    signal wifiPassword(var network, string error)
}
