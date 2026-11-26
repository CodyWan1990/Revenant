import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Artwork and plain-text MPRIS metadata.
RowLayout {
    id: root

    property var player: null
    property int artSize: 64
    property int titleSize: Services.Ui.textSubtitle
    property int artistSize: Services.Ui.textBody
    property int albumSize: Services.Ui.textSmall
    property int textSpacing: 2
    property bool showArtworkPlaceholder: false

    spacing: 12

    Rectangle {
        Layout.preferredWidth: root.artSize
        Layout.preferredHeight: root.artSize
        visible: root.showArtworkPlaceholder || artwork.status === Image.Ready
        color: Services.Colors.primaryContainer
        clip: true

        StyledText {
            anchors.centerIn: parent
            visible: artwork.status !== Image.Ready
            text: "♪"
            color: Services.Colors.primaryContainerText
            font.pixelSize: root.artSize / 3
        }

        Image {
            id: artwork
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize.width: root.artSize
            sourceSize.height: root.artSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        Layout.fillWidth: true
        spacing: root.textSpacing

        StyledText {
            width: parent.width
            text: root.player?.trackTitle ?? ""
            color: Services.Colors.foreground
            font.pixelSize: root.titleSize
            font.bold: true
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            text: root.player?.trackArtist ?? ""
            color: Services.Colors.surfaceVariantText
            font.pixelSize: root.artistSize
            elide: Text.ElideRight
            visible: text !== ""
        }
        StyledText {
            width: parent.width
            text: root.player?.trackAlbum ?? ""
            color: Services.Colors.surfaceVariantText
            font.pixelSize: root.albumSize
            elide: Text.ElideRight
            visible: text !== ""
        }
    }
}
