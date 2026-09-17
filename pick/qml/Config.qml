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
    property alias flowMaxWidth: adapter.flowMaxWidth

    FileView {
        path: Qt.resolvedUrl("config.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property int collapsedWidth: 145
            property int collapsedHeight: 32
            property int expandedWidth: 520
            property int expandedHeight: 386
            property int cornerWing: 16
            property int canvasWidth: 552
            property int canvasHeight: 450
            property int radius: 15
            property real trayMaxSize: 32
            property real trayMinSize: 18
            property real trayFalloff: 1.4
            property int clockFormat: 12
            property bool clockShowSeconds: true
            property int flowMaxWidth: 380
        }
    }
}
