import QtQuick
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Network speed widget — download/upload rates. Click: a popup with both,
/// and their history (download filled, upload as a line).
BarUi.BarWidget {
    id: root
    icon: "net"
    defaultAccent: Services.Colors.networkUnderline
    clickable: true
    onClicked: popup.isOpen ? popup.close() : popup.open()
    text: Services.Fmt.fill(instance.format ?? "↓{rx} ↑{tx}", {
        rx: Services.SystemStats.netRx,
        tx: Services.SystemStats.netTx
    })

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 360
        accentColor: root.accent

        Components.StatPopup {
            headerText: "Network"
            leftValue: Services.SystemStats.netRx
            leftLabel: "download"
            rightValue: Services.SystemStats.netTx
            rightLabel: "upload"
            graphValues: Services.SystemStats.rxHistory
            graphColor: root.accent
            graphValues2: Services.SystemStats.txHistory
            graphColor2: Services.Colors.color5
            graphMax: 0
            graphName: "Download"
            graphName2: "Upload"
            graphFormat: value => Services.SystemStats.formatRate(value)
        }
    }
}
