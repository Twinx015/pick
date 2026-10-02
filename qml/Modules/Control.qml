import QtQuick
import Quickshell
import Quickshell.Io

// Helper components live in ControlButton.qml and SectionHeader.qml.
Item {
    id: control

    property string activeSection: ""
    property bool wifiOn: false
    property bool bluetoothOn: false
    property string connectedSsid: ""
    property int brightness: -1
    property int maxBrightness: 100
    property string backlightDev: ""

    readonly property real btnWidth: 92
    readonly property real detailWidth: control.width - control.btnWidth - 10

    ListModel {
        id: wifiModel
    }
    ListModel {
        id: btModel
    }

    // ------------------------------------------------ backend state

    Process {
        id: wifiStatusProc

        running: false
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: control.wifiOn = this.text.trim().toLowerCase() === "enabled"
        }
    }

    Process {
        id: wifiListProc

        running: false
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: control.parseWifiList(this.text)
        }
    }

    Process {
        id: wifiRescanProc

        running: false
        command: ["nmcli", "dev", "wifi", "rescan"]
        stdout: StdioCollector {}
        onExited: {
            delayed.interval = 2000;
            delayed.action = control.refreshWifi;
            delayed.restart();
        }
    }

    Process {
        id: wifiToggleProc

        running: false
        command: []
        stdout: StdioCollector {}
    }

    Process {
        id: wifiConnectProc

        running: false
        command: []
        stdout: StdioCollector {}
    }

    Process {
        id: btStatusProc

        running: false
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: control.parseBtStatus(this.text)
        }
    }

    Process {
        id: btListProc

        running: false
        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: control.parseBtList(this.text)
        }
    }

    Process {
        id: btConnectedProc

        running: false
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: control.parseBtConnected(this.text)
        }
    }

    Process {
        id: btToggleProc

        running: false
        command: []
        stdout: StdioCollector {}
    }

    Process {
        id: btConnectProc

        running: false
        command: []
        stdout: StdioCollector {}
    }

    Process {
        id: backlightFindProc

        running: false
        command: ["sh", "-c", "ls /sys/class/backlight/ 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                control.backlightDev = this.text.trim();
                control.loadBacklight();
            }
        }
    }

    Process {
        id: maxReadProc

        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim());
                if (!isNaN(v) && v > 0)
                    control.maxBrightness = v;
            }
        }
    }

    Process {
        id: briReadProc

        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim());
                if (!isNaN(v))
                    control.brightness = v;
            }
        }
    }

    Process {
        id: briWriteProc

        running: false
        command: []
        stdout: StdioCollector {}
    }

    Timer {
        id: delayed

        property var action: null
        interval: 2000
        onTriggered: {
            if (delayed.action) {
                delayed.action();
                delayed.action = null;
            }
        }
    }

    Timer {
        id: briDebounce

        property int pending: -1
        interval: 60
        onTriggered: {
            if (briDebounce.pending >= 0) {
                var v = Math.max(0, Math.min(control.maxBrightness, briDebounce.pending));
                briWriteProc.command = ["sh", "-c", "echo " + v + " > /sys/class/backlight/" + control.backlightDev + "/brightness"];
                briWriteProc.running = true;
                briDebounce.pending = -1;
            }
        }
    }

    Timer {
        interval: 3000
        running: control.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiStatusProc.running = true;
            btStatusProc.running = true;
            control.loadBacklight();
            if (control.activeSection === "wifi")
                control.refreshWifi();
            else if (control.activeSection === "bluetooth")
                control.loadBluetooth();
        }
    }

    onActiveSectionChanged: {
        if (control.activeSection === "wifi")
            control.refreshWifi();
        else if (control.activeSection === "bluetooth")
            control.loadBluetooth();
    }

    onBrightnessChanged: {
        if (control.brightness >= 0)
            briSlider.pos = control.brightness / Math.max(1, control.maxBrightness);
    }

    // ------------------------------------------------ helpers

    function splitEscaped(line) {
        var out = [];
        var cur = "";
        for (var i = 0; i < line.length; i++) {
            var ch = line.charAt(i);
            if (ch === "\\" && i + 1 < line.length) {
                cur += line.charAt(i + 1);
                i++;
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    function signalIcon(signal) {
        if (signal >= 75) return "󰤨"; // md-wifi_strength_4
        if (signal >= 50) return "󰤥"; // md-wifi_strength_3
        if (signal >= 25) return "󰤢"; // md-wifi_strength_2
        return "󰤟"; // md-wifi_strength_1
    }

    function findConnected(entries) {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].connected)
                return entries[i].ssid;
        }
        return "";
    }

    function parseWifiList(text) {
        var entries = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var f = control.splitEscaped(line);
            if (f.length < 3)
                continue;
            var ssid = f[0].trim();
            if (ssid.length === 0)
                continue;
            var signal = parseInt(f[1]);
            if (isNaN(signal))
                signal = 0;
            var inUse = (f[3] || "").indexOf("*") !== -1;
            entries.push({ ssid: ssid, signal: signal, security: f[2] || "", connected: inUse });
        }
        entries.sort(function(a, b) { return b.signal - a.signal; });
        wifiModel.clear();
        for (var j = 0; j < entries.length; j++)
            wifiModel.append(entries[j]);
        control.connectedSsid = control.findConnected(entries);
    }

    function parseBtStatus(text) {
        var m = text.match(/Powered:\s*(yes|no)/i);
        if (m)
            control.bluetoothOn = m[1].toLowerCase() === "yes";
    }

    function parseBtList(text) {
        btModel.clear();
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var parts = line.split(/\s+/);
            if (parts.length < 3 || parts[0] !== "Device")
                continue;
            btModel.append({ mac: parts[1], name: parts.slice(2).join(" "), connected: false });
        }
        btConnectedProc.running = true;
    }

    function parseBtConnected(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var parts = line.split(/\s+/);
            if (parts.length < 2 || parts[0] !== "Device")
                continue;
            for (var j = 0; j < btModel.count; j++) {
                if (btModel.get(j).mac === parts[1]) {
                    btModel.setProperty(j, "connected", true);
                    break;
                }
            }
        }
    }

    function toggleSection(section) {
        control.activeSection = control.activeSection === section ? "" : section;
    }

    function refreshWifi() {
        wifiListProc.running = true;
    }

    function rescanWifi() {
        wifiRescanProc.running = true;
    }

    function setWifi(on) {
        wifiToggleProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiToggleProc.running = true;
        control.wifiOn = on;
        control.refreshWifi();
    }

    function connectWifi(ssid) {
        wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        wifiConnectProc.running = true;
        delayed.interval = 1500;
        delayed.action = control.refreshWifi;
        delayed.restart();
    }

    function loadBluetooth() {
        btListProc.running = true;
    }

    function setBluetooth(on) {
        btToggleProc.command = ["bluetoothctl", "power", on ? "on" : "off"];
        btToggleProc.running = true;
        control.bluetoothOn = on;
        control.loadBluetooth();
    }

    function toggleDevice(mac, connect) {
        btConnectProc.command = ["bluetoothctl", connect ? "connect" : "disconnect", mac];
        btConnectProc.running = true;
        delayed.interval = 1200;
        delayed.action = control.loadBluetooth;
        delayed.restart();
    }

    function loadBacklight() {
        if (control.backlightDev === "") {
            backlightFindProc.running = true;
            return;
        }
        maxReadProc.command = ["cat", "/sys/class/backlight/" + control.backlightDev + "/max_brightness"];
        briReadProc.command = ["cat", "/sys/class/backlight/" + control.backlightDev + "/brightness"];
        maxReadProc.running = true;
        briReadProc.running = true;
    }

    function setBrightness(value) {
        control.brightness = value;
        briDebounce.pending = value;
        briDebounce.restart();
    }

    // ------------------------------------------------ ui

    Row {
        anchors.fill: parent
        spacing: 10

        Column {
            id: buttons

            width: control.btnWidth
            spacing: 8

            ControlButton {
                width: control.btnWidth
                iconText: control.wifiOn ? "󰖩" : "󰖪"
                labelText: "Wi-Fi"
                active: control.activeSection === "wifi"
                powered: control.wifiOn
                onClicked: control.toggleSection("wifi")
            }

            ControlButton {
                width: control.btnWidth
                iconText: control.bluetoothOn ? "󰂯" : "󰂲"
                labelText: "Bluetooth"
                active: control.activeSection === "bluetooth"
                powered: control.bluetoothOn
                onClicked: control.toggleSection("bluetooth")
            }

            ControlButton {
                width: control.btnWidth
                iconText: "󰃟" // md-brightness_6
                labelText: "Screen"
                active: control.activeSection === "brightness"
                powered: control.brightness >= 0
                onClicked: control.toggleSection("brightness")
            }
        }

        Item {
            id: detailSlot

            width: control.activeSection === "" ? 0 : control.detailWidth
            height: parent.height
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "#121216"
                border.color: "#303036"
                border.width: 1
                clip: true

                Item {
                    id: detailContent

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: control.detailWidth
                    clip: true

                    // ---- Wi-Fi panel ----
                    Item {
                        anchors.fill: parent
                        visible: control.activeSection === "wifi"

                        SectionHeader {
                            id: wifiHeader

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            title: "Wi-Fi"
                            showRefresh: true
                            showSwitch: true
                            checked: control.wifiOn
                            onClosed: control.toggleSection("wifi")
                            onRefreshed: control.rescanWifi()
                            onToggled: control.setWifi(on)
                        }

                        ListView {
                            id: wifiList

                            anchors.top: wifiHeader.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            clip: true
                            model: wifiModel
                            spacing: 4

                            delegate: Rectangle {
                                width: wifiList.width
                                height: 38
                                radius: 6
                                color: wifiItemHover.containsMouse ? "#202024" : "transparent"

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10

                                    Text {
                                        id: wifiSigIcon

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: control.signalIcon(model.signal)
                                        color: model.connected ? "#8fd49f" : "#a5a5a5"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        id: wifiItemLock

                                        visible: model.security !== ""
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰌾" // md-lock
                                        color: "#8b8b90"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        id: wifiItemConn

                                        visible: model.connected
                                        anchors.right: wifiItemLock.visible ? wifiItemLock.left : parent.right
                                        anchors.rightMargin: wifiItemLock.visible ? 8 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Connected"
                                        color: "#8fd49f"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.left: wifiSigIcon.right
                                        anchors.leftMargin: 8
                                        anchors.right: wifiItemConn.visible
                                                   ? wifiItemConn.left
                                                   : (wifiItemLock.visible ? wifiItemLock.left : parent.right)
                                        anchors.rightMargin: wifiItemLock.visible ? 8 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.ssid !== "" ? model.ssid : "(Hidden Network)"
                                        color: "#f2f2f2"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: wifiItemHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: control.connectWifi(model.ssid)
                                }
                            }
                        }

                        Item {
                            anchors.fill: wifiList
                            visible: !control.wifiOn || wifiModel.count === 0

                            Text {
                                anchors.centerIn: parent
                                text: !control.wifiOn ? "Wi-Fi is off" : "No networks found"
                                color: "#6a6a70"
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ---- Bluetooth panel ----
                    Item {
                        anchors.fill: parent
                        visible: control.activeSection === "bluetooth"

                        SectionHeader {
                            id: btHeader

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            title: "Bluetooth"
                            showSwitch: true
                            checked: control.bluetoothOn
                            onClosed: control.toggleSection("bluetooth")
                            onToggled: control.setBluetooth(on)
                        }

                        ListView {
                            id: btList

                            anchors.top: btHeader.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            clip: true
                            model: btModel
                            spacing: 4

                            delegate: Rectangle {
                                width: btList.width
                                height: 44
                                radius: 6
                                color: btItemHover.containsMouse ? "#202024" : "transparent"

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10

                                    Text {
                                        id: btAudioIcon

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰂰" // md-bluetooth_audio
                                        color: model.connected ? "#8fd49f" : "#a5a5a5"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        id: btItemConn

                                        visible: model.connected
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Connected"
                                        color: "#8fd49f"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    Column {
                                        anchors.left: btAudioIcon.right
                                        anchors.leftMargin: 8
                                        anchors.right: btItemConn.visible ? btItemConn.left : parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: model.name
                                            color: "#f2f2f2"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: model.mac
                                            color: "#6a6a70"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btItemHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: control.toggleDevice(model.mac, !model.connected)
                                }
                            }
                        }

                        Item {
                            anchors.fill: btList
                            visible: !control.bluetoothOn || btModel.count === 0

                            Text {
                                anchors.centerIn: parent
                                text: !control.bluetoothOn ? "Bluetooth is off" : "No known devices"
                                color: "#6a6a70"
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ---- Brightness panel ----
                    Item {
                        anchors.fill: parent
                        visible: control.activeSection === "brightness"

                        SectionHeader {
                            id: briHeader

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            title: "Brightness"
                            onClosed: control.toggleSection("brightness")
                        }

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 12

                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    id: briHeaderIcon

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰃟" // md-brightness_6
                                    color: "#f0f0f0"
                                    font.pixelSize: 16
                                }

                                Text {
                                    anchors.left: briHeaderIcon.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Screen brightness"
                                    color: "#f2f2f2"
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: control.brightness >= 0
                                          ? Math.round(100 * control.brightness / Math.max(1, control.maxBrightness)) + "%"
                                          : "--%"
                                    color: "#8fd49f"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            Item {
                                id: briSlider

                                property real pos: 0

                                width: parent.width
                                height: 30

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: "#2c2c30"
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * briSlider.pos
                                    height: 6
                                    radius: 3
                                    color: "#3f8fe0"
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: width / 2
                                    color: "#e8e8e8"
                                    x: parent.width * briSlider.pos - width / 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: briSlider.setFrom(mouse.x)
                                    onPositionChanged: if (pressed) briSlider.setFrom(mouse.x)
                                }

                                function setFrom(mx) {
                                    var p = Math.max(0, Math.min(1, mx / width));
                                    briSlider.pos = p;
                                    control.setBrightness(Math.round(p * control.maxBrightness));
                                }
                            }

                            Text {
                                text: "Backlight: " + (control.maxBrightness > 0 ? control.maxBrightness : "?") + " steps"
                                color: "#6a6a70"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}