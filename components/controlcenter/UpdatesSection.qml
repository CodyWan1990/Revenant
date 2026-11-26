import QtQuick
import "../../services" as Services
import ".." as Components

/// The Control Center's Updates section:
/// system / Flatpak / Snap lists with their upgrade buttons, and Refresh.
/// `actionStarted` fires when an upgrade starts (it opens a terminal), so the
/// caller can close its dropdown.
Column {
    id: root

    signal actionStarted()

    width: parent ? parent.width : 400
    spacing: 8

    Components.StyledText {
        visible: Services.Updates.checking
        text: "Checking for updates…"
        color: Services.Colors.surfaceVariantText
        font.pixelSize: Services.Ui.textBodyLarge
    }

    // A failed check is not "up to date".
    Components.StyledText {
        width: parent.width
        visible: !Services.Updates.checking && Services.Updates.errors.length > 0
        text: "Couldn't check: " + Services.Updates.errors.join(" · ")
        color: Services.Colors.red
        font.pixelSize: Services.Ui.textBody
        wrapMode: Text.Wrap
    }

    Components.StyledText {
        visible: !Services.Updates.checking && Services.Updates.totalCount === 0 && Services.Updates.errors.length === 0
        text: "✅ All packages are up to date."
        color: Services.Colors.green
        font.pixelSize: Services.Ui.textBodyLarge
    }

    PackageUpdateSection {
        visible: !Services.Updates.checking
        icon: "💻"
        title: "System"
        count: Services.Updates.count
        packages: Services.Updates.packages
        detailWidth: 200
        detailText: packageData => (packageData.current || "")
            + " → " + (packageData.new || "")
        actionText: "⬆ Upgrade System"
        actionColor: Services.Colors.updatesUnderline
        onActionRequested: {
            root.actionStarted();
            Services.Updates.upgradeSystem();
        }
    }

    Components.Divider { opacity: 1.0; visible: !Services.Updates.checking }

    PackageUpdateSection {
        visible: !Services.Updates.checking
        icon: "📦"
        title: "Flatpak"
        count: Services.Updates.flatpakCount
        packages: Services.Updates.flatpakPackages
        detailText: packageData => packageData.id || ""
        actionText: "⬆ Update Flatpaks"
        actionColor: Services.Colors.color5
        onActionRequested: {
            root.actionStarted();
            Services.Updates.upgradeFlatpaks();
        }
    }

    Components.Divider { opacity: 1.0; visible: !Services.Updates.checking && Services.Updates.snapCount > 0 }

    PackageUpdateSection {
        visible: !Services.Updates.checking && Services.Updates.snapCount > 0
        icon: "🧩"
        title: "Snap"
        count: Services.Updates.snapCount
        packages: Services.Updates.snapPackages
        detailWidth: 200
        detailText: packageData => packageData.current && packageData.current !== packageData.new
            ? packageData.current + " → " + packageData.new : "new revision"
        actionText: "⬆ Update Snaps"
        actionColor: Services.Colors.color3
        onActionRequested: {
            root.actionStarted();
            Services.Updates.upgradeSnaps();
        }
    }

    Components.Divider { opacity: 1.0; visible: !Services.Updates.checking }

    Components.TextButton {
        text: "↻ Refresh All"
        horizontalPadding: 8
        enabled: !Services.Updates.checking
        onClicked: Services.Updates.refresh()
    }
}
