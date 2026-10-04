import QtQuick
import "../"

// Month grid for the Calendar tab. Events come from CalendarData.qml, which
// reads *.ics files; days carrying events get a dot under the number and the
// agenda underneath lists whichever day is selected.
Item {
    id: cal

    property int firstWeekday: Config.calendarFirstWeekday

    // Section heights. The month grid gets a capped cell height so it can't
    // starve the agenda underneath it, which is where the actual events are.
    property int headerH: 26
    property int weekdaysH: 14
    property int dividerH: 1
    property int labelH: 15
    property int gapH: 6
    property int minCell: 22
    property int maxCell: 30
    property int minAgenda: 84

    // layout Column insets by 4 on every side and spaces its 5 children.
    readonly property int innerH: Math.max(0, cal.height - 8)
    readonly property int fixedH: cal.headerH + cal.weekdaysH + cal.dividerH + cal.labelH + cal.gapH * 4
    readonly property int cellHeight: Math.max(cal.minCell, Math.min(cal.maxCell,
        Math.floor((cal.innerH - cal.fixedH - cal.minAgenda) / 6)))
    readonly property int agendaH: Math.max(0, cal.innerH - cal.fixedH - cal.cellHeight * 6)

    CalendarData {
        id: calData
        folders: Config.calendarFolders
    }

    // Month currently on screen.
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()

    // Day-key of the cell the user clicked.
    property int selectedKey: cal.todayKey

    readonly property var today: new Date()
    readonly property int todayKey: calData.keyOfDate(new Date())

    readonly property var monthNames: Qt.locale().standaloneMonthNames
    readonly property var shortDayNames: {
        const raw = Qt.locale().dayNames;
        return raw ? raw.map(s => s.slice(0, 2)) : ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
    }

    readonly property string monthLabel: {
        const names = cal.monthNames && cal.monthNames.length === 12 ? cal.monthNames : ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return names[cal.month] + " " + cal.year;
    }

    // 42 day keys covering the visible grid, starting on the first weekday of
    // the week that contains the 1st.
    readonly property var cells: {
        const first = new Date(cal.year, cal.month, 1);
        // JS getDay() is 0=Sunday; shift so 1=Monday.
        let lead = first.getDay() - cal.firstWeekday + 1;
        if (lead < 0)
            lead += 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(cal.year, cal.month, 1 - lead + i);
            out.push({
                key: calData.dayKey(d.getFullYear(), d.getMonth(), d.getDate()),
                day: d.getDate(),
                inMonth: d.getMonth() === cal.month
            });
        }
        return out;
    }

    readonly property var selectedEvents: calData.eventsOn(cal.selectedKey)

    readonly property string selectedLabel: {
        const d = new Date(cal.selectedKey * 86400000);
        const names = Qt.locale().standaloneMonthNames;
        const name = names && names.length === 12 ? names[d.getUTCMonth()] : "Month";
        return name + " " + d.getUTCDate();
    }

    function stepMonth(delta) {
        let m = cal.month + delta;
        let y = cal.year;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        cal.month = m;
        cal.year = y;
    }

    function goToday() {
        const now = new Date();
        cal.month = now.getMonth();
        cal.year = now.getFullYear();
        cal.selectedKey = cal.todayKey;
    }

    Column {
        id: layout

        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        // ---- month header ----
        Item {
            width: parent.width
            height: cal.headerH

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cal.monthLabel
                color: "#f5f5f5"
                font.pixelSize: 14
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: todayHover.containsMouse ? "#1e1e22" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰃶" // md-calendar_today
                        color: todayHover.containsMouse ? "#f5f5f5" : "#8a8a90"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: todayHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.goToday()
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: prevHover.containsMouse ? "#1e1e22" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁" // md-chevron_left
                        color: prevHover.containsMouse ? "#f5f5f5" : "#8a8a90"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: prevHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.stepMonth(-1)
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: nextHover.containsMouse ? "#1e1e22" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂" // md-chevron_right
                        color: nextHover.containsMouse ? "#f5f5f5" : "#8a8a90"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: nextHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.stepMonth(1)
                    }
                }
            }
        }

        // ---- weekday labels ----
        Item {
            width: parent.width
            height: cal.weekdaysH

            Repeater {
                model: 7

                delegate: Text {
                    required property int index

                    width: layout.width / 7
                    height: cal.weekdaysH
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        // Qt dayNames start at Monday; rotate to match firstWeekday.
                        const names = cal.shortDayNames;
                        const offset = (cal.firstWeekday - 1 + index) % 7;
                        return names.length === 7 ? names[offset] : "";
                    }
                    color: "#5f5f66"
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        // ---- month grid ----
        Grid {
            width: parent.width
            height: cal.cellHeight * 6
            columns: 7

            Repeater {
                model: cal.cells

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool selected: cell.modelData.key === cal.selectedKey
                    readonly property bool isToday: cell.modelData.key === cal.todayKey
                    readonly property var events: calData.eventsOn(cell.modelData.key)

                    // Mirrored from the MouseArea below: a delegate's own bindings
                    // are evaluated before its children exist.
                    property bool hover: false

                    width: layout.width / 7
                    height: cal.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 3
                        radius: 7
                        color: cell.selected ? "#2a2a30" : (cell.hover ? "#1b1b1f" : "transparent")
                        border.color: cell.isToday && !cell.selected ? "#4a4a52" : "transparent"
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        color: !cell.modelData.inMonth ? "#3f3f46" : (cell.selected ? "#ffffff" : (cell.isToday ? "#f5f5f5" : "#c9c9cd"))
                        font.pixelSize: 11
                        font.bold: cell.selected || cell.isToday
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 3
                        height: 3
                        radius: 1.5
                        visible: cell.events.length > 0
                        color: cell.modelData.inMonth ? (cell.selected ? "#f5f5f5" : "#8fd49f") : "#3f3f46"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: cell.hover = true
                        onExited: cell.hover = false
                        onClicked: {
                            cal.selectedKey = cell.modelData.key;
                            if (!cell.modelData.inMonth) {
                                const d = new Date(cell.modelData.key * 86400000);
                                cal.month = d.getUTCMonth();
                                cal.year = d.getUTCFullYear();
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: cal.dividerH
            color: "#1f1f23"
        }

        // ---- agenda for the selected day ----
        Text {
            width: parent.width
            height: cal.labelH
            text: cal.selectedLabel
            color: "#9a9aa2"
            font.pixelSize: 10
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Item {
            id: agendaBox

            width: parent.width
            height: cal.agendaH

            ListView {
                id: agenda

                anchors.fill: parent
                clip: true
                spacing: 3
                model: cal.selectedEvents
                boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row

                required property var modelData

                width: agenda.width
                height: 26

                Rectangle {
                    width: 3
                    height: 18
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.allDay ? "#8a8a90" : "#3f8fe0"
                }

                Text {
                    id: when

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    text: row.modelData.allDay ? "all day" : (row.modelData.minutes >= 0 ? (Math.floor(row.modelData.minutes / 60) + ":" + (row.modelData.minutes % 60 < 10 ? "0" : "") + (row.modelData.minutes % 60)) : "")
                    color: "#6a6a70"
                    font.pixelSize: 9
                    font.family: "monospace"
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: when.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.summary
                    color: "#e6e6ea"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            }

            // Empty state lives inside agendaBox rather than the Column: a
            // Positioner assigns child positions itself, so anchors on its
            // children are ignored.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: agenda.count === 0
                text: calData.eventCount === 0 ? "No .ics files found in ~/Calendar" : "Nothing scheduled"
                color: "#5f5f66"
                font.pixelSize: 10
            }
        }
    }
}