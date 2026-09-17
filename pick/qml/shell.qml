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

    readonly property bool showFlow: flow.isPlaying && !expanded && !hovered
    readonly property real infoWidth: Math.max(collapsedWidth, statusRow.implicitWidth + 24)
    readonly property real collapsedTargetWidth: showFlow ? flow.pillWidth : infoWidth
    readonly property real targetWidth: expanded ? expandedWidth : collapsedTargetWidth
    readonly property real targetHeight: expanded ? expandedHeight : collapsedHeight

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
            onClicked: window.expanded = !window.expanded
            onEntered: window.hovered = true
            onExited: window.hovered = false
        }

        Item {
            anchors.fill: parent
            clip: true

            Flow {
                id: flow

                mode: window.expanded ? "panel" : "pill"
                width: window.showFlow ? flow.pillWidth : parent.width
                height: window.showFlow ? flow.pillHeight : parent.height
                anchors.centerIn: parent
                visible: window.showFlow || window.expanded
            }

            Row {
                id: statusRow

                spacing: 14
                anchors.centerIn: parent
                visible: !window.showFlow && !window.expanded

                Clock {}
                Battery {}
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
