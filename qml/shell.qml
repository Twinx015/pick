import QtQuick
import QtQuick.Shapes
import Quickshell
import "Modules"

PanelWindow {
    id: window

    readonly property int collapsedWidth: Config.collapsedWidth
    readonly property int collapsedHeight: Config.collapsedHeight
    readonly property int expandedWidth: Config.expandedWidth
    readonly property int expandedHeight: Config.expandedHeight
    readonly property int cornerWing: Config.cornerWing
    readonly property int canvasWidth: Config.canvasWidth
    readonly property int canvasHeight: Config.canvasHeight
    readonly property color fill: "#000000"
    readonly property color foreground: "#ffffff"
    readonly property int radius: Config.radius
    property bool expanded: false
    property bool hovered: false

    // ------------------------------------------------ tabs

    // Sections shown inside the expanded notch, cycled with Tab / Shift+Tab.
    readonly property var tabs: [
        {
            "key": "control",
            "label": "Control",
            "icon": "󰘮" // md-tune
        },
        {
            "key": "media",
            "label": "Media",
            "icon": "󰲸" // md-playlist_music
        },
        {
            "key": "calendar",
            "label": "Calendar",
            "icon": "󰸗" // md-calendar_month
        },
        {
            "key": "system",
            "label": "System",
            "icon": "󰕮" // md-view_dashboard
        }
    ]
    property int tabIndex: 0

    readonly property string activeTab: tabs[tabIndex].key

    function setTab(key) {
        for (let i = 0; i < window.tabs.length; i++) {
            if (window.tabs[i].key === key) {
                window.tabIndex = i;
                return;
            }
        }
    }

    function cycleTab(direction) {
        const count = window.tabs.length;
        window.tabIndex = (window.tabIndex + direction + count) % count;
    }

    // ------------------------------------------------ geometry

    // Collapsed pill: shown while a track is loaded, not only while playing, so it
    // doesn't blink on every pause.
    readonly property bool showMedia: media.hasSession && !expanded && !hovered
    readonly property real infoWidth: Math.max(collapsedWidth, statusRow.implicitWidth + 24)
    readonly property real collapsedTargetWidth: showMedia ? media.pillWidth : infoWidth
    readonly property real targetWidth: expanded ? expandedWidth : collapsedTargetWidth
    readonly property real targetHeight: expanded ? expandedHeight : collapsedHeight

    readonly property int tabBarHeight: 26
    readonly property int tabBarTop: 10
    readonly property int contentTop: tabBarTop + tabBarHeight + 10
    readonly property int contentInset: 12

    margins.left: Math.round((screen.width - canvasWidth) / 2)
    implicitWidth: canvasWidth
    implicitHeight: canvasHeight
    color: "transparent"
    aboveWindows: true
    focusable: expanded

    anchors {
        top: true
        left: true
    }

    FocusScope {
        id: notchSurface

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: window.targetWidth
        height: window.targetHeight
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                window.expanded = false;
                event.accepted = true;
                return;
            }
            if (!window.expanded)
                return;
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                window.cycleTab(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier) ? 1 : -1);
                event.accepted = true;
            }
        }

        Rectangle {
            id: notchBody

            x: window.cornerWing
            y: -15
            width: parent.width - window.cornerWing * 2
            height: parent.height + 15
            radius: window.radius
            color: window.fill
        }

        Shape {
            x: 0
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: leftShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: window.fill
                startX: 0
                startY: 0

                PathLine {
                    x: leftShoulderPath.size
                    y: 0
                }

                PathLine {
                    x: leftShoulderPath.size
                    y: leftShoulderPath.size
                }

                PathCubic {
                    control1X: leftShoulderPath.size
                    control1Y: leftShoulderPath.size * 0.448
                    control2X: leftShoulderPath.size * 0.552
                    control2Y: 0
                    x: 0
                    y: 0
                }
            }
        }

        Shape {
            x: parent.width - width
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: rightShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: window.fill
                startX: rightShoulderPath.size
                startY: 0

                PathLine {
                    x: 0
                    y: 0
                }

                PathLine {
                    x: 0
                    y: rightShoulderPath.size
                }

                PathCubic {
                    control1X: 0
                    control1Y: rightShoulderPath.size * 0.448
                    control2X: rightShoulderPath.size * 0.448
                    control2Y: 0
                    x: rightShoulderPath.size
                    y: 0
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!window.expanded) window.expanded = true
            onEntered: window.hovered = true
            onExited: window.hovered = false
        }

        Item {
            anchors.fill: parent
            clip: true

            // ------------------------------------------------ collapsed

            Media {
                id: media

                mode: window.expanded ? "panel" : "pill"
                x: window.expanded ? window.contentInset : Math.max(0, (parent.width - width) / 2)
                y: window.expanded ? window.contentTop : Math.max(0, (parent.height - media.pillHeight) / 2)
                width: window.expanded ? parent.width - window.contentInset * 2 : (window.showMedia ? media.pillWidth : parent.width)
                height: window.expanded ? Math.max(0, parent.height - window.contentTop - 12) : media.pillHeight
                visible: window.expanded ? window.activeTab === "media" : window.showMedia
            }

            Row {
                id: statusRow

                spacing: 14
                anchors.centerIn: parent
                visible: !window.showMedia && !window.expanded

                Clock {}
                Battery {}
            }

            // ------------------------------------------------ expanded

            TabBar {
                id: tabBar

                x: window.contentInset
                y: window.tabBarTop
                width: parent.width - window.contentInset * 2
                height: window.tabBarHeight
                visible: window.expanded
                tabs: window.tabs
                currentIndex: window.tabIndex
                tabHeight: window.tabBarHeight
                onTabClicked: key => window.setTab(key)
            }

            Item {
                id: contentArea

                x: window.contentInset
                y: window.contentTop
                width: parent.width - window.contentInset * 2
                height: Math.max(0, parent.height - window.contentTop - 12)
                visible: window.expanded

                Control {
                    id: controlCenter

                    anchors.fill: parent
                    visible: window.activeTab === "control"
                }

                Calendar {
                    id: calendarPanel

                    anchors.fill: parent
                    visible: window.activeTab === "calendar"
                }

                System {
                    id: systemPanel

                    anchors.fill: parent
                    visible: window.activeTab === "system"
                }
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }

    mask: Region {
        item: notchBody
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: window.radius
        bottomRightRadius: window.radius
    }

    SystemTray {
        id: systemTray
        active: window.expanded

        anchors {
            top: notchSurface.bottom
            horizontalCenter: notchSurface.horizontalCenter
            topMargin: 8
        }
    }
}