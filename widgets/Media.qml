import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// MPRIS media player widget — track info + prev/play/next controls; click track info to open player popup.
/// The audio visualiser is built in (Dux Shell's media widget, MIT): small bars
/// beside the track on the bar and/or a wide strip in the popup
/// (`visualizer`: both | bar | popup | off), fed by the shared cava.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    Layout.fillHeight: true
    // Zero width (not just invisible) with no player, so the bar leaves no gap.
    implicitWidth: activePlayer !== null ? playerRow.implicitWidth + 10 : 0
    visible: activePlayer !== null

    property var activePlayer: Services.Media.playingPlayer
    readonly property string viz: instance.visualizer ?? "both"
    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.mprisUnderline)

    BarUi.BarItem {
        style: root.instance.style ?? "underline"
        accentColor: root.accent

        RowLayout {
            id: playerRow
            anchors.centerIn: parent
            spacing: 6

            Components.MediaTransportControls {
                visible: root.instance.showControls ?? true
                player: root.activePlayer
                spacing: 8
                sideSize: root.bar?.fontSize ?? 14
                playSize: root.bar?.fontSize ?? 14
                accentColor: root.accent
                Layout.alignment: Qt.AlignVCenter
            }

            // Visualiser beside the track (only while playing).
            BarUi.CavaBars {
                visible: (root.viz === "both" || root.viz === "bar") && root.playing && Services.Cava.available
                active: visible
                bars: root.instance.vizBars ?? 8
                barWidth: 3
                maxHeight: (root.bar ? root.bar.implicitHeight : 30) - 12
                color: root.accent
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                font.family: root.bar?.fontFamily ?? ""
                font.pixelSize: root.bar?.smallFontSize ?? 12
                font.weight: Font.DemiBold
                color: root.playing ? Services.Colors.foreground : Services.Colors.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: root.instance.maxWidth ?? 250
                textFormat: Text.RichText

                text: {
                    if (!root.activePlayer) return "";
                    let set = Services.Icons.resolveSet(root.instance.iconSet ?? "auto");
                    let icon = set === "none" ? ""
                        : (set === "nerd" || set === "material") ? Services.Icons.markup("music", set, root.accent)
                        : Services.Media.playerIcon(root.activePlayer.identity);
                    let title = root.activePlayer.trackTitle || "";
                    let artist = root.activePlayer.trackArtist || "";
                    // Placeholders expand to "" when the player reports nothing, so
                    // collapse the separators an empty field leaves behind.
                    let display = Services.Fmt.fill(root.instance.format ?? "{artist} - {title}", {
                        artist: artist,
                        title: title,
                        album: root.activePlayer.trackAlbum || "",
                        player: root.activePlayer.identity || ""
                    }).replace(/^[\s\-—:]+|[\s\-—:]+$/g, "");
                    let max = root.instance.maxChars ?? 35;
                    if (display.length > max) display = display.substring(0, Math.max(1, max - 3)) + "...";
                    return (icon === "" ? "" : icon + " ") + Services.Icons.esc(display);
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mprisPopup.isOpen ? mprisPopup.close() : mprisPopup.open()
                }
            }
        }
    }

    Components.WidgetPopup {
        id: mprisPopup
        bar: root.bar
        parentWidget: root
        contentWidth: 380
        accentColor: root.accent

        // Inner FocusScope for Space key (Escape bubbles up to WidgetPopup's FocusScope)
        // Must use explicit sizing (not anchors.fill) so childrenRect auto-height works
        FocusScope {
            width: parent.width
            height: popupCol.implicitHeight
            focus: true
            Keys.onSpacePressed: root.activePlayer?.togglePlaying()

            Column {
                id: popupCol
                width: parent.width
                spacing: 10

                Components.PopupHeader {
                    text: root.activePlayer?.identity || "Media"
                    showClose: true
                    showSeparator: false
                    onCloseClicked: mprisPopup.close()
                }

                Rectangle {
                    width: parent.width
                    height: trackInfo.implicitHeight + 20
                    color: Services.Colors.surfaceContainerHigh
                    border.color: Services.Colors.outlineVariant
                    border.width: 1

                    Components.MediaTrackInfo {
                        id: trackInfo
                        anchors.fill: parent
                        anchors.margins: 10
                        player: root.activePlayer
                        showArtworkPlaceholder: true
                        artSize: 80
                        titleSize: Services.Ui.textTitle
                        artistSize: Services.Ui.textBodyLarge
                        textSpacing: 4
                    }
                }

                // Wide visualiser strip under the track info.
                Item {
                    width: parent.width
                    height: 28
                    visible: (root.viz === "both" || root.viz === "popup") && Services.Cava.available

                    BarUi.CavaBars {
                        anchors.centerIn: parent
                        active: mprisPopup.isOpen && root.playing
                        bars: 32
                        barWidth: Math.max(1, Math.floor((parent.width - 31 * 3) / 32))
                        spacing: 3
                        maxHeight: 26
                        color: root.accent
                    }
                }

                Components.MediaSeekBar {
                    width: parent.width
                    player: root.activePlayer
                    accentColor: root.accent
                    trackColor: Services.Colors.surfaceContainerHighest
                    trackHeight: 6
                }

                Components.MediaTransportControls {
                    anchors.horizontalCenter: parent.horizontalCenter
                    player: root.activePlayer
                    accentColor: root.accent
                    buttonSurfaces: true
                    sideSize: 20
                    playSize: 24
                    spacing: 10
                }
            }
        }
    }
}
