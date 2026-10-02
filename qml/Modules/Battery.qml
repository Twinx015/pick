import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: battery

    implicitWidth: batteryText.implicitWidth
    implicitHeight: batteryText.implicitHeight
    visible: batteryText.text.length > 0

    Text {
        id: batteryText

        text: ""
        color: "#f5f5f5"
        font.pixelSize: 13
        anchors.centerIn: parent
    }

    Process {
        id: batteryProc

        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var pct = parseInt(this.text.trim());
                if (!isNaN(pct)) {
                    var icon = pct >= 90 ? "󰁹" : pct >= 70 ? "󰂀" : pct >= 50 ? "󰁾" : pct >= 30 ? "󰁼" : pct >= 10 ? "󰁺" : "󰂃";
                    batteryText.text = icon + " " + pct + "%";
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryProc.running = true
    }
}