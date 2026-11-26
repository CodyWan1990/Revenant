import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Three-segment clock: day, date, time.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    Layout.fillHeight: true
    implicitWidth: row.implicitWidth

    // Qt format strings; "" hides the segment.
    readonly property string weekdayFormat: instance.weekdayFormat ?? "dddd"
    readonly property string dateFormat: instance.dateFormat ?? "MMMM d, yyyy"
    readonly property string timeFormat: instance.timeFormat ?? "hh:mm AP"

    // Native reactive clock. Tick per minute unless the time format asks for
    // seconds — per-minute is documented battery best-practice, and it also
    // avoids rebuilding the calendar grid every second.
    SystemClock {
        id: clock
        precision: root.timeFormat.indexOf("s") >= 0 ? SystemClock.Seconds : SystemClock.Minutes
    }
    property date now: clock.date
    // Viewed month for calendar navigation, independent of real time.
    property date viewDate: new Date()

    BarUi.BarItem {
        style: root.instance.style ?? "underline"
        accentColor: Services.Colors.byKey(root.instance.color, Services.Colors.clockUnderline)

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Item {
            visible: root.weekdayFormat !== ""
            Layout.fillHeight: true
            Layout.preferredWidth: visible ? dayText.implicitWidth + 10 : 0
            Layout.topMargin: 1
            Layout.bottomMargin: 1

            Text {
                id: dayText
                anchors.centerIn: parent
                textFormat: Text.RichText
                text: Services.Icons.prefix("calendar", root.instance.iconSet ?? "emoji", Services.Colors.byKey(root.instance.color, Services.Colors.clockUnderline)) + root.now.toLocaleDateString(Qt.locale(), root.weekdayFormat)
                color: Services.Colors.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: root.bar.fontSize
                font.weight: Font.Bold
            }

        }

        Item {
            visible: root.dateFormat !== ""
            Layout.fillHeight: true
            Layout.preferredWidth: visible ? dateText.implicitWidth + 10 : 0
            Layout.topMargin: 1
            Layout.bottomMargin: 1

            Text {
                textFormat: Text.PlainText
                id: dateText
                anchors.centerIn: parent
                text: root.now.toLocaleDateString(Qt.locale(), root.dateFormat)
                color: Services.Colors.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: root.bar.fontSize
                font.weight: Font.Bold
            }


            MouseArea {
                anchors.fill: parent
                onClicked: calendarPopup.isOpen ? calendarPopup.close() : calendarPopup.open()
            }
        }

        Item {
            visible: root.timeFormat !== ""
            Layout.fillHeight: true
            Layout.preferredWidth: visible ? timeText.implicitWidth + 10 : 0
            Layout.topMargin: 1
            Layout.bottomMargin: 1

            Text {
                id: timeText
                anchors.centerIn: parent
                textFormat: Text.RichText
                text: ((root.instance.timeIcon ?? true) ? Services.Icons.prefix("clock", root.instance.iconSet ?? "emoji", Services.Colors.byKey(root.instance.color, Services.Colors.clockUnderline)) : "") + root.now.toLocaleTimeString(Qt.locale(), root.timeFormat)
                color: Services.Colors.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: root.bar.fontSize
                font.weight: Font.Bold
            }

        }
    }
    }

    Components.WidgetPopup {
        id: calendarPopup
        bar: root.bar
        parentWidget: root
        contentWidth: 330
        contentMargins: 16
        accentColor: Services.Colors.clockUnderline
        fadeInDuration: 500
        fadeOutDuration: 300
        useOpenDelay: true
        xClamp: 0
        onOpening: root.viewDate = new Date(root.now)

        readonly property color accent: widgetAccent
        readonly property int cellWidth: Math.floor(width > 0 ? (contentWidth - contentMargins * 2) / 7 : 42)

        Column {
            width: parent.width
            spacing: 12

            // ── Today, at a glance (click: back to this month) ──
            Rectangle {
                width: parent.width
                height: hero.implicitHeight + 24
                radius: Services.Ui.radiusMd
                color: heroMA.containsMouse ? Services.Colors.surfaceContainerHighest
                                            : Services.Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: hero
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    spacing: 14

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.now.getDate()
                        color: calendarPopup.accent
                        font.family: root.bar.fontFamily
                        font.pixelSize: Services.Ui.px(44)
                        font.bold: true
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            textFormat: Text.PlainText
                            text: root.now.toLocaleDateString(Qt.locale(), "dddd")
                            color: Services.Colors.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Services.Ui.textSubtitle
                            font.bold: true
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: root.now.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            color: Services.Colors.surfaceVariantText
                            font.family: root.bar.fontFamily
                            font.pixelSize: Services.Ui.textBody
                        }
                    }
                }

                MouseArea {
                    id: heroMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.viewingToday ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            // ── Month navigation ──
            Item {
                width: parent.width
                height: 30

                Rectangle {
                    id: prevButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30
                    radius: Services.Ui.radiusSm
                    color: prevMA.containsMouse ? Services.Colors.surfaceContainerHighest : "transparent"
                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "\u2039"
                        color: prevMA.containsMouse ? calendarPopup.accent : Services.Colors.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Services.Ui.textTitle
                        font.bold: true
                    }
                    MouseArea {
                        id: prevMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                        color: Services.Colors.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Services.Ui.textBodyLarge
                        font.bold: true
                    }
                    // Only when another month is shown.
                    Rectangle {
                        visible: !root.viewingToday
                        anchors.verticalCenter: parent.verticalCenter
                        width: todayLabel.implicitWidth + 14
                        height: todayLabel.implicitHeight + 6
                        radius: height / 2
                        color: todayMA.containsMouse ? calendarPopup.accent : "transparent"
                        border.width: 1
                        border.color: calendarPopup.accent
                        Text {
                            id: todayLabel
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: "Today"
                            color: todayMA.containsMouse ? Services.Colors.background : calendarPopup.accent
                            font.family: root.bar.fontFamily
                            font.pixelSize: Services.Ui.textCaption
                            font.bold: true
                        }
                        MouseArea {
                            id: todayMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToToday()
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30
                    radius: Services.Ui.radiusSm
                    color: nextMA.containsMouse ? Services.Colors.surfaceContainerHighest : "transparent"
                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "\u203A"
                        color: nextMA.containsMouse ? calendarPopup.accent : Services.Colors.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Services.Ui.textTitle
                        font.bold: true
                    }
                    MouseArea {
                        id: nextMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            // ── The month (scroll to change it) ──
            Column {
                width: parent.width
                spacing: 4

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: root.weekdays()
                        Text {
                            required property var modelData
                            textFormat: Text.PlainText
                            width: calendarPopup.cellWidth
                            text: modelData.name
                            color: modelData.weekend ? calendarPopup.accent : Services.Colors.surfaceVariantText
                            font.family: root.bar.fontFamily
                            font.pixelSize: Services.Ui.textSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7

                    Repeater {
                        model: root.calendarDays()
                        delegate: Item {
                            id: cell
                            required property var modelData
                            width: calendarPopup.cellWidth
                            height: 36

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32; height: 32
                                radius: cell.modelData.isToday ? 16 : Services.Ui.radiusSm
                                visible: cell.modelData.day > 0 && (cell.modelData.isToday || dayMA.containsMouse)
                                color: cell.modelData.isToday ? calendarPopup.accent : Services.Colors.surfaceContainerHighest
                            }
                            Text {
                                textFormat: Text.PlainText
                                anchors.centerIn: parent
                                visible: cell.modelData.day > 0
                                text: cell.modelData.day
                                color: cell.modelData.isToday ? Services.Colors.background
                                     : cell.modelData.weekend ? Services.Colors.surfaceVariantText
                                     : Services.Colors.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Services.Ui.textBody
                                font.bold: cell.modelData.isToday
                            }
                            MouseArea {
                                id: dayMA
                                anchors.fill: parent
                                hoverEnabled: cell.modelData.day > 0
                            }
                        }
                    }
                }

                // Wheel or touchpad: one month per notch (touchpads accumulate).
                WheelHandler {
                    property real acc: 0
                    onWheel: event => {
                        acc += event.angleDelta.y;
                        while (acc >= 120) { acc -= 120; root.prevMonth(); }
                        while (acc <= -120) { acc += 120; root.nextMonth(); }
                    }
                }
            }
        }
    }

    readonly property bool viewingToday: viewDate.getFullYear() === now.getFullYear()
        && viewDate.getMonth() === now.getMonth()

    function prevMonth() {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1);
    }
    function nextMonth() {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1);
    }
    function goToToday() {
        viewDate = new Date(now);
    }

    /// The locale's week, from its first day: [{ name, weekend }].
    function weekdays(): list<var> {
        const first = Qt.locale().firstDayOfWeek % 7;   // 0 = Sunday
        let out = [];
        for (let i = 0; i < 7; i++) {
            const d = (first + i) % 7;
            out.push({ name: Qt.locale().dayName(d, Locale.ShortFormat).slice(0, 2), weekend: d === 0 || d === 6 });
        }
        return out;
    }

    /// The viewed month as whole weeks (5 or 6 rows; 4 for a February that
    /// fits): days of other months are blank cells, { day: 0 }.
    function calendarDays(): list<var> {
        const year = viewDate.getFullYear();
        const month = viewDate.getMonth();
        const first = Qt.locale().firstDayOfWeek % 7;
        const lead = (new Date(year, month, 1).getDay() - first + 7) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        let days = [];
        for (let i = 0; i < lead; i++) days.push({ day: 0, weekend: false, isToday: false });
        for (let d = 1; d <= daysInMonth; d++) {
            const weekday = new Date(year, month, d).getDay();
            days.push({
                day: d,
                weekend: weekday === 0 || weekday === 6,
                isToday: d === now.getDate() && month === now.getMonth() && year === now.getFullYear()
            });
        }
        while (days.length % 7 !== 0) days.push({ day: 0, weekend: false, isToday: false });
        return days;
    }
}
