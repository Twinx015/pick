pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias collapsedWidth: adapter.collapsedWidth
    property alias collapsedHeight: adapter.collapsedHeight
    property alias expandedWidth: adapter.expandedWidth
    property alias expandedHeight: adapter.expandedHeight
    property alias cornerWing: adapter.cornerWing
    property alias canvasWidth: adapter.canvasWidth
    property alias canvasHeight: adapter.canvasHeight
    property alias radius: adapter.radius
    property alias trayMaxSize: adapter.trayMaxSize
    property alias trayMinSize: adapter.trayMinSize
    property alias trayFalloff: adapter.trayFalloff
    property alias clockFormat: adapter.clockFormat
    property alias clockShowSeconds: adapter.clockShowSeconds
    property alias calendarFolders: adapter.calendarFolders
    property alias calendarFirstWeekday: adapter.calendarFirstWeekday
    property alias systemInterval: adapter.systemInterval
    property alias mediaIgnore: adapter.mediaIgnore
    property alias mediaShowPaused: adapter.mediaShowPaused

    FileView {
        path: Qt.resolvedUrl("config.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property int collapsedWidth: 145
            property int collapsedHeight: 32
            property int expandedWidth: 550
            property int expandedHeight: 440
            property int cornerWing: 16
            property int canvasWidth: 552
            property int canvasHeight: 500
            property int radius: 15
            property real trayMaxSize: 32
            property real trayMinSize: 18
            property real trayFalloff: 1.4
            property int clockFormat: 12
            property bool clockShowSeconds: true
            // Comma separated .ics folders for the Calendar tab.
            property string calendarFolders: "~/Calendar,~/.local/share/calendar"
            // 1 = Monday ... 7 = Sunday
            property int calendarFirstWeekday: 1
            // System tab sample interval in milliseconds.
            property int systemInterval: 2000
            // Comma separated player ids to hide. Browsers implement MPRIS for
            // tab audio, so without this they take over the collapsed pill and
            // the dot switcher shows tabs instead of players.
            property string mediaIgnore: "firefox,firefox-esr,librewolf,zen,chromium,chromium-browser,chrome,google-chrome,brave,brave-browser,vivaldi,vivaldi-stable,opera,edge,msedge,qutebrowser,epiphany,midori,falkon"
            // Keep the pill visible while a track is loaded but paused.
            property bool mediaShowPaused: true
        }
    }
}
