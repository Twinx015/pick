import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Effects

Item {
    id: flow

    property string mode: "pill"

    property bool isPlaying: statusText === "playing"
    property bool isIdleStatus: statusText === "not playing"
    property bool hasSession: nowPlaying.length > 0
    property string statusText: "not playing"
    property string nowPlaying: ""
    property string duration: ""
    property string thumbnailSource: ""
    property string thumbDisplay: ""
    property string pendingUrl: ""
    property string lastFetchedUrl: ""
    property bool isLastPlayed: false
    property string homeDir: ""

    readonly property real flowMaxWidth: Config.flowMaxWidth
    readonly property real minPillWidth: Config.collapsedWidth
    readonly property real pillHeight: Config.collapsedHeight
    readonly property real pillTitleWidth: 150
    readonly property real pillWidth: Math.max(minPillWidth, pillTitleWidth + 50)

    Process {
        id: statusProc
        command: ["flow", "--status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: flow.parseStatus(this.text)
        }
    }
    Process {
        id: homeProc
        command: ["sh", "-c", "echo $HOME"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: flow.homeDir = this.text.trim()
        }
    }
    Process {
        id: prevProc
        command: ["flow", "--previous"]
        running: false
    }
    Process {
        id: toggleProc
        command: ["flow", "--stop"]
        running: false
    }
    Process {
        id: nextProc
        command: ["flow", "--next"]
        running: false
    }

    Timer {
        id: thumbDebounce

        interval: 200
        onTriggered: {
            const target = flow.pendingUrl;
            if (target.length === 0 || target !== flow.thumbnailSource)
                return;
            if (thumbDl.running)
                return;
            const out = "/tmp/qsisland-" + target.replace(/[^a-zA-Z0-9]/g, "").slice(-48);
            thumbDl.url = target;
            thumbDl.outPath = out;
            thumbDl.command = ["curl", "-sLf", "--max-time", "15", "-o", out, "--", target];
            thumbDl.running = true;
        }
    }

    Process {
        id: thumbDl

        property string url: ""
        property string outPath: ""
        command: []
        stdout: StdioCollector {}
        onExited: {
            if (exitCode === 0 && url === flow.pendingUrl && url === flow.thumbnailSource) {
                flow.lastFetchedUrl = url;
                flow.thumbDisplay = outPath;
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusProc.running = true;
            if (flow.homeDir === "")
                homeProc.running = true;
        }
    }

    function stripAnsi(text) {
        return text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "");
    }
    function resolveThumbnail(raw) {
        const t = raw.trim();
        if (/^https?:\/\//i.test(t))
            return t;
        let p = t.startsWith("~") ? flow.homeDir + t.substring(1) : t;
        if (p.startsWith("/downloads/") || p.startsWith("/cache/") || p.startsWith("/.cache/")) {
            p = flow.homeDir + "/.flow" + p;
        }
        return p;
    }
    function ensureThumb(resolved) {
        if (!/^https?:\/\//i.test(resolved)) {
            thumbDebounce.stop();
            if (thumbDl.running)
                thumbDl.running = false;
            flow.pendingUrl = "";
            flow.thumbDisplay = resolved;
            return;
        }
        if (resolved === flow.lastFetchedUrl)
            return;
        if (thumbDl.running && thumbDl.url !== resolved)
            thumbDl.running = false;
        flow.pendingUrl = resolved;
        thumbDebounce.restart();
    }
    function parseStatus(rawText) {
        const text = flow.stripAnsi(rawText);
        const statusMatch = text.match(/status\s*:\s*(.+)/i);
        const nowMatch = text.match(/currently playing\s*:\s*(.+)/i);
        const lastMatch = text.match(/last played\s*:\s*(.+)/i);
        const durMatch = text.match(/total duration\s*:\s*(.+)/i);
        const thumbMatch = text.match(/thumbnail\s*:\s*(.+)/i);

        flow.statusText = statusMatch ? statusMatch[1].trim() : "not playing";
        flow.thumbnailSource = thumbMatch ? flow.resolveThumbnail(thumbMatch[1].trim()) : "";
        flow.ensureThumb(flow.thumbnailSource);

        if (nowMatch) {
            flow.nowPlaying = nowMatch[1].trim();
            flow.isLastPlayed = false;
        } else if (lastMatch) {
            flow.nowPlaying = lastMatch[1].trim();
            flow.isLastPlayed = true;
        } else {
            flow.nowPlaying = "";
            flow.isLastPlayed = false;
        }

        flow.duration = durMatch ? durMatch[1].trim() : "";
    }

    Row {
        id: pillRow

        spacing: 10
        anchors.centerIn: parent
        visible: flow.mode === "pill"

        Text {
            id: titleText

            text: flow.nowPlaying
            color: "#f5f5f5"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            width: flow.pillTitleWidth
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        anchors.fill: parent
        visible: flow.mode === "panel"

        Rectangle {
            id: controlBox

            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 40
            height: parent.height * 0.2
            radius: 5
            color: "#0e0e0e"
            clip: true

            Item {
                id: thumbArea
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                anchors.leftMargin: 6
                width: parent.height - 12
                visible: flow.thumbDisplay.length > 0

                Image {
                    id: glowSource
                    anchors.centerIn: parent
                    width: parent.width * 2.0
                    height: parent.height * 2.0
                    source: flow.thumbDisplay
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    source: glowSource
                    anchors.fill: glowSource
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 72
                    opacity: 0.5
                }

                MultiEffect {
                    source: glowSource
                    anchors.centerIn: glowSource
                    width: glowSource.width * 0.7
                    height: glowSource.height * 0.7
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 40
                    opacity: 0.35
                }

                Rectangle {
                    id: thumbBox
                    anchors.fill: parent
                    radius: width / 2
                    color: "#1a1a1c"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: flow.thumbDisplay
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        mipmap: true
                        asynchronous: true
                        cache: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0.55
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#55000000"
                            }
                        }
                    }
                }
            }

            Column {
                anchors.left: flow.thumbDisplay.length > 0 ? thumbArea.right : parent.left
                anchors.leftMargin: flow.thumbDisplay.length > 0 ? 14 : 6
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                spacing: 2

                Text {
                    text: flow.nowPlaying
                    color: "#f5f5f5"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: flow.duration
                    color: "#999999"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text.length > 0
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                spacing: 10

                Rectangle {
                    id: prevCircle
                    width: 40
                    height: 40
                    radius: width / 2
                    anchors.verticalCenterOffset: -8
                    color: prevArea.containsMouse ? "#262626" : "#242426"
                    border.color: prevArea.containsMouse ? "#3a3a3d" : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰼨"
                        color: prevArea.containsMouse ? "#f5f5f5" : "#999999"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: prevProc.running = true
                    }
                }

                Rectangle {
                    id: toggleCircle
                    width: 56
                    height: 56
                    radius: width / 2
                    anchors.verticalCenterOffset: 10
                    color: toggleArea.containsMouse ? "#2e2e31" : "#1c1c1e"
                    border.color: toggleArea.containsMouse ? "#4a4a4d" : "#2a2a2c"
                    border.width: 1

                    property bool playing: false

                    Rectangle {
                        id: pulse
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "transparent"
                        border.color: "#e5e5e5"
                        border.width: 2
                        opacity: 0
                        scale: 1
                    }

                    Text {
                        id: playIcon
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 2
                        text: "󰐊"
                        color: toggleArea.containsMouse ? "#ffffff" : "#e5e5e5"
                        font.pixelSize: 30
                        opacity: toggleCircle.playing ? 1 : 0
                        scale: toggleCircle.playing ? 1 : 0.4
                        rotation: toggleCircle.playing ? 0 : -90

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        id: pauseIcon
                        anchors.centerIn: parent
                        text: "󰏤"
                        color: toggleArea.containsMouse ? "#ffffff" : "#e5e5e5"
                        font.pixelSize: 30
                        opacity: toggleCircle.playing ? 0 : 1
                        scale: toggleCircle.playing ? 0.4 : 1
                        rotation: toggleCircle.playing ? 90 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            toggleProc.running = true;
                            toggleCircle.playing = !toggleCircle.playing;
                            pulseScaleAnim.start();
                            pulseOpacityAnim.start();
                        }
                    }

                    NumberAnimation {
                        id: pulseScaleAnim
                        target: pulse
                        property: "scale"
                        from: 1.0
                        to: 1.35
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: pulseOpacityAnim
                        target: pulse
                        property: "opacity"
                        from: 0.6
                        to: 0
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: nextCircle
                    width: 40
                    height: 40
                    radius: width / 2
                    anchors.verticalCenterOffset: -8
                    color: nextArea.containsMouse ? "#262626" : "#242426"
                    border.color: nextArea.containsMouse ? "#3a3a3d" : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰼧"
                        color: nextArea.containsMouse ? "#f5f5f5" : "#999999"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: nextProc.running = true
                    }
                }
            }
        }
    }
}
