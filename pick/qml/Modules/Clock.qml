import QtQuick
import "../"

Item {
    id: clock

    readonly property bool military: Config.clockFormat === 24

    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

    function formatTime() {
        var now = new Date();
        var h = now.getHours();
        var m = now.getMinutes();
        var s = now.getSeconds();
        if (!clock.military)
            h = h % 12 || 12;
        var time = h + ":" + (m < 10 ? "0" : "") + m;
        return time;
    }

    Text {
        id: clockText

        text: clock.formatTime()
        color: "#f5f5f5"
        font.pixelSize: 13
        font.bold: true
        font.family: "monospace"
        anchors.centerIn: parent
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clockText.text = clock.formatTime()
    }
}
