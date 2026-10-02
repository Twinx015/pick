import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// System tab: CPU, RAM, ROM (firmware) and storage readouts.
//
// Everything comes straight from /proc, /sys and df, so there is no extra
// dependency. Only polls while the tab is actually on screen.
Item {
    id: sys

    property int intervalMs: Config.systemInterval

    // ------------------------------------------------ parsed state

    property real cpuPercent: 0
    property int cpuCores: 0
    property string cpuName: ""
    property string loadAvg: ""

    property double memTotal: 0
    property double memUsed: 0
    property double memAvailable: 0
    property double swapTotal: 0
    property double swapUsed: 0

    property double romBytes: -1
    property string biosVersion: ""
    property string biosDate: ""

    property string gpuName: ""
    property string gpuVendor: ""
    property string gpuIds: ""
    property string kernel: ""
    property double uptimeSeconds: -1

    // [{ device, mount, total, used, ratio }]
    property var filesystems: []

    readonly property bool memKnown: memTotal > 0
    readonly property double memRatio: memKnown ? memUsed / memTotal : -1
    readonly property double swapRatio: swapTotal > 0 ? swapUsed / swapTotal : -1

    // ------------------------------------------------ samplers

    Process {
        id: statProc

        running: false
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseStat(this.text)
        }
    }

    Process {
        id: memProc

        running: false
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseMeminfo(this.text)
        }
    }

    Process {
        id: loadProc

        running: false
        command: ["cat", "/proc/loadavg"]
        stdout: StdioCollector {
            onStreamFinished: sys.loadAvg = this.text.trim()
        }
    }

    Process {
        id: uptimeProc

        running: false
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(this.text.trim().split(/\s+/)[0]);
                if (!isNaN(v))
                    sys.uptimeSeconds = v;
            }
        }
    }

    Process {
        id: cpuInfoProc

        running: false
        command: ["sh", "-c", "cat /proc/cpuinfo; echo ---; cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null; cat /sys/devices/virtual/dmi/id/bios_date 2>/dev/null; uname -r"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseDmi(this.text)
        }
    }

    Process {
        id: diskProc

        running: false
        command: ["sh", "-c", "df -B1 --output=source,fstype,size,used,avail,target 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseDf(this.text)
        }
    }

    Process {
        id: gpuNameProc

        running: false
        command: ["sh", "-c", "for d in /sys/class/drm/card[0-9]*; do [ -e \"$d/device/vendor\" ] || continue; v=$(cat $d/device/vendor); dev=$(cat $d/device/device); v=${v#0x}; dev=${dev#0x}; n=$(lspci -nn 2>/dev/null | grep -i \"\\[${v}:${dev}\\]\" | sed 's/.*: //; s/ \\[.*//'); echo \"$v:$dev|$n\"; done"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseGpuNames(this.text)
        }
    }

    Process {
        id: romProc

        running: false
        command: ["sh", "-c", "du -sb /sys/firmware 2>/dev/null | cut -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim());
                sys.romBytes = isNaN(v) ? -1 : v;
            }
        }
    }

    Process {
        id: gpuProc

        running: false
        command: ["sh", "-c", "for d in /sys/class/drm/card[0-9]*; do [ -e \"$d/device/vendor\" ] || continue; echo \"$(cat $d/device/vendor):$(cat $d/device/device)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: sys.parseGpu(this.text)
        }
    }

    Timer {
        interval: sys.intervalMs
        running: sys.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: sys.sample()
    }

    Component.onCompleted: sys.loadStatic()

    // ------------------------------------------------ driving

    function sample() {
        statProc.running = true;
        memProc.running = true;
        loadProc.running = true;
        uptimeProc.running = true;
        diskProc.running = true;
    }

    function loadStatic() {
        cpuInfoProc.running = true;
        romProc.running = true;
        gpuProc.running = true;
    }

    // lspci resolves the marketing name from the ids gathered above.
    onGpuIdsChanged: if (gpuIds !== "")
        gpuNameProc.running = true;

    // ------------------------------------------------ parsing

    property real prevBusy: -1
    property real prevTotal: -1
    property real prevIdle: 0

    function parseStat(text) {
        const line = text.split("\n")[0];
        if (!line.startsWith("cpu "))
            return;
        const f = line.trim().split(/\s+/);
        let total = 0;
        let idle = parseInt(f[4]) || 0;
        for (let i = 1; i < f.length; i++)
            total += parseInt(f[i]) || 0;
        if (f.length > 5)
            idle += parseInt(f[5]) || 0;

        if (sys.prevTotal >= 0) {
            const dTotal = total - sys.prevTotal;
            const dIdle = idle - sys.prevIdle;
            if (dTotal > 0) {
                const used = Math.max(0, Math.min(1, (dTotal - dIdle) / dTotal));
                sys.cpuPercent = Math.round(sys.cpuPercent * 0.4 + used * 100 * 0.6);
            }
        }
        sys.prevBusy = total - idle;
        sys.prevTotal = total;
        sys.prevIdle = idle;
    }

    function parseMeminfo(text) {
        const out = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = /^([A-Za-z_()]+):\s+(\d+)/.exec(lines[i]);
            if (m)
                out[m[1]] = parseInt(m[2]) * 1024;
        }
        if (out.MemTotal !== undefined) {
            sys.memTotal = out.MemTotal;
            sys.memAvailable = out.MemAvailable !== undefined ? out.MemAvailable : (out.MemFree || 0);
            sys.memUsed = Math.max(0, sys.memTotal - sys.memAvailable);
            sys.swapTotal = out.SwapTotal || 0;
            sys.swapUsed = sys.swapTotal > 0 ? Math.max(0, sys.swapTotal - (out.SwapFree || 0)) : 0;
        }
    }

    function parseDmi(text) {
        const parts = text.split("---");
        const cpuPart = parts.length > 0 ? parts[0] : "";
        const dmiPart = parts.length > 1 ? parts[1] : "";

        const cores = {};
        const lines = cpuPart.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const c = /^processor\s*:\s*(\d+)/.exec(lines[i]);
            if (c)
                cores[c[1]] = true;
            const m = /^model name\s*:\s*(.+)/.exec(lines[i]);
            if (m && sys.cpuName === "")
                sys.cpuName = m[1].trim();
        }
        sys.cpuCores = Object.keys(cores).length;

        const dmiLines = dmiPart.split("\n");
        for (let i = 0; i < dmiLines.length; i++) {
            const line = dmiLines[i].trim();
            if (line === "" )
                continue;
            if (/^\d{1,2}[\w.\-/ ]*$/.test(line) && sys.biosVersion === "")
                sys.biosVersion = line;
            else if (/^\d{2}\/\d{2}\/\d{4}$/.test(line) && sys.biosDate === "")
                sys.biosDate = line;
            else if (sys.kernel === "")
                sys.kernel = line;
        }
    }

    // Virtual filesystems carry no useful capacity information.
    readonly property var ignoredFsTypes: ["tmpfs", "devtmpfs", "squashfs", "overlay", "iso9660", "efivarfs", "ramfs", "rootfs", "autofs", "fuse.sshfs", "fuse.gvfsd-fuse", "debugfs", "tracefs", "configfs", "fusectl", "mqueue", "hugetlbfs", "binfmt_misc", "pstore", "securityfs", "bpf", "nsfs", "cgroup", "cgroup2", "devfs", "proc", "sysfs", "gfs2", "nfs", "cifs"]

    function parseDf(text) {
        const rows = [];
        const lines = text.split("\n");
        // Keep the shallowest mount per device: btrfs subvolumes and bind
        // mounts all report the same backing device, and listing each one
        // would just be the same bar repeated.
        const best = {};

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "" || /^Filesystem/i.test(line))
                continue;

            // Mount targets may contain spaces, so parse from both ends and
            // keep the remainder as the mount path.
            const m = /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/.exec(line);
            if (!m)
                continue;

            const device = m[1];
            const fstype = m[2];
            const total = parseInt(m[3]);
            const used = parseInt(m[4]);
            const mount = m[6].trim();

            if (total <= 0 || mount === "" || sys.ignoredFsTypes.indexOf(fstype) !== -1)
                continue;
            if (device.indexOf("/dev") !== 0)
                continue;

            const existing = best[device];
            if (existing !== undefined) {
                // Prefer "/", then the shortest path (fewest segments).
                const better = (existing.mount !== "/" && (mount === "/" || mount.length < existing.mount.length));
                if (!better)
                    continue;
            }

            best[device] = {
                device: device,
                fstype: fstype,
                mount: mount,
                total: total,
                used: used,
                ratio: used / total
            };
        }

        for (const device in best) {
            if (Object.prototype.hasOwnProperty.call(best, device))
                rows.push(best[device]);
        }

        rows.sort((a, b) => {
            if (a.mount === "/")
                return -1;
            if (b.mount === "/")
                return 1;
            return a.mount < b.mount ? -1 : 1;
        });
        sys.filesystems = rows;
    }

    function parseGpu(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line !== "")
                sys.gpuIds = line;
            else
                break;
        }
        if (lines.length === 0)
            sys.gpuIds = "";
    }

    // "<vendorId>:<deviceId>|<name from lspci>" lines.
    function parseGpuNames(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            const sep = line.indexOf("|");
            if (sep < 0)
                continue;
            const ids = line.slice(0, sep).trim().toLowerCase();
            const name = line.slice(sep + 1).trim();
            if (sys.gpuIds.indexOf(ids) !== -1) {
                sys.gpuName = name !== "" ? name : ("GPU " + ids.replace(":", " "));
                sys.gpuVendor = "";
                return;
            }
        }
        if (sys.gpuIds !== "") {
            sys.gpuName = "GPU " + sys.gpuIds.replace(":", " ");
            sys.gpuVendor = "";
        }
    }

    // ------------------------------------------------ formatting

    function bytes(v) {
        if (v === undefined || v === null || isNaN(v))
            return "--";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let n = v;
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return (i === 0 ? n.toFixed(0) : n.toFixed(n >= 100 ? 0 : (n >= 10 ? 1 : 2))) + " " + units[i];
    }

    function duration(seconds) {
        if (seconds < 0 || isNaN(seconds))
            return "--";
        const s = Math.floor(seconds);
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    function mountLabel(entry) {
        return entry.mount === "/" ? "/ root" : entry.mount;
    }

    // ------------------------------------------------ ui

    Flickable {
        id: scroller

        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body

            width: scroller.width
            spacing: 10

            // ---- tile grid ----
            Grid {
                width: parent.width
                columns: 2
                spacing: 10

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󰻠" // md-cpu_64_bit
                    valueText: sys.cpuPercent + "%"
                    labelText: "CPU"
                    subText: sys.cpuCores > 0 ? sys.cpuCores + (sys.cpuCores === 1 ? " core" : " cores") : ""
                    ratio: sys.cpuPercent / 100
                    accent: "#e0a33f"
                }

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󰻠" // md-memory
                    valueText: sys.memKnown ? sys.bytes(sys.memUsed) : "--"
                    labelText: "RAM"
                    subText: sys.memKnown ? "of " + sys.bytes(sys.memTotal) : "unavailable"
                    ratio: sys.memRatio
                    accent: sys.memRatio >= 0.9 ? "#e0554a" : "#3f8fe0"
                }

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󰘚" // md-chip
                    valueText: sys.romBytes >= 0 ? sys.bytes(sys.romBytes) : "--"
                    labelText: "ROM"
                    subText: sys.biosVersion !== "" ? sys.biosVersion : "firmware"
                    ratio: -1
                    accent: "#8a7fd4"
                }

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󰓡" // md-swap_horizontal
                    valueText: sys.swapTotal > 0 ? sys.bytes(sys.swapUsed) : "off"
                    labelText: "Swap"
                    subText: sys.swapTotal > 0 ? "of " + sys.bytes(sys.swapTotal) : "not configured"
                    ratio: sys.swapRatio
                    accent: "#4fae7a"
                }

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󰓅" // md-speedometer
                    valueText: sys.loadAvg.split(" ")[0] || "--"
                    labelText: "Load average"
                    subText: sys.loadAvg !== "" ? sys.loadAvg.split(" ").slice(0, 3).join("  ") : ""
                    ratio: -1
                    accent: "#3f8fe0"
                }

                Metric {
                    width: (body.width - 10) / 2
                    iconText: "󱎫" // md-timer
                    valueText: sys.uptimeSeconds >= 0 ? sys.duration(sys.uptimeSeconds) : "--"
                    labelText: "Uptime"
                    subText: sys.kernel !== "" ? sys.kernel : ""
                    ratio: -1
                    accent: "#3f8fe0"
                }
            }

            // ---- storage ----
            Text {
                text: "Storage"
                color: "#9a9aa2"
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: Math.max(46, sys.filesystems.length * 40 + 16)
                radius: 9
                color: "#101014"
                border.color: "#242428"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Repeater {
                        model: sys.filesystems

                        delegate: Item {
                            id: disk

                            required property var modelData

                            width: parent.width
                            height: 32

                            Text {
                                id: diskIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰋊" // md-harddisk
                                color: disk.modelData.ratio >= 0.9 ? "#e0554a" : "#6a6a70"
                                font.pixelSize: 12
                            }

                            Text {
                                id: diskMount

                                anchors.left: diskIcon.right
                                anchors.leftMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                width: 76
                                text: sys.mountLabel(disk.modelData)
                                color: "#e6e6ea"
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideLeft
                            }

                            Text {
                                anchors.left: diskMount.right
                                anchors.leftMargin: 6
                                anchors.right: diskBar.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: disk.modelData.device
                                color: "#4a4a50"
                                font.pixelSize: 8
                                elide: Text.ElideMiddle
                            }

                            Item {
                                id: diskBar

                                anchors.right: diskUsed.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72
                                height: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: "#26262a"
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * Math.max(0, Math.min(1, disk.modelData.ratio))
                                    height: 4
                                    radius: 2
                                    color: disk.modelData.ratio >= 0.9 ? "#e0554a" : "#3f8fe0"

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 220
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            Text {
                                id: diskUsed

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 68
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(disk.modelData.ratio * 100) + "%  " + sys.bytes(disk.modelData.total)
                                color: "#8a8a90"
                                font.pixelSize: 9
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: sys.filesystems.length === 0
                        text: "No mounted filesystems reported"
                        color: "#5f5f66"
                        font.pixelSize: 10
                    }
                }
            }

            // ---- gpu / hardware footer ----
            Rectangle {
                width: parent.width
                height: 46
                radius: 9
                color: "#101014"
                border.color: "#242428"
                border.width: 1
                visible: sys.gpuName !== "" || sys.cpuName !== ""

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "󰻠" // md-cpu_64_bit
                        color: "#4a4a50"
                        font.pixelSize: 12
                    }

                    Text {
                        width: Math.max(0, parent.width - 22)
                        text: {
                            const parts = [];
                            if (sys.cpuName !== "")
                                parts.push(sys.cpuName);
                            if (sys.gpuName !== "")
                                parts.push(sys.gpuName);
                            return parts.join("  ·  ");
                        }
                        color: "#6a6a70"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}