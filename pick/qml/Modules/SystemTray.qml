import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: trayRoot

    property bool active: false
    property real focusIndex: 0
    readonly property real maxSize: 32
    readonly property real minSize: 18
    readonly property real falloff: 1.4
    property bool rowHovered: false

    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight
    opacity: active ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }

    HoverHandler {
        id: trayHover
        target: trayRoot
        onHoveredChanged: trayRoot.rowHovered = trayHover.hovered
    }

    WheelHandler {
        target: trayRoot
        onWheel: event => {
            if (!trayRoot.rowHovered)
                return;
            const count = SystemTray.items.count;
            if (count <= 0)
                return;
            const delta = event.angleDelta.y > 0 ? -1 : 1;
            trayRoot.focusIndex = Math.max(0, Math.min(count - 1, trayRoot.focusIndex + delta * 0.35));
        }
    }

    Row {
        id: trayRow
        spacing: 8
        anchors.centerIn: parent

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItemDelegate

                required property SystemTrayItem modelData
                required property int index

                readonly property real distance: Math.abs(index - trayRoot.focusIndex)
                readonly property real magnify: trayRoot.rowHovered ? Math.max(0, 1 - distance / trayRoot.falloff) : 0
                readonly property real targetSize: trayRoot.minSize + (trayRoot.maxSize - trayRoot.minSize) * magnify

                width: targetSize
                height: targetSize
                radius: 10
                color: "#222222"

                Behavior on width {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: parent.height - 6
                    fillMode: Image.PreserveAspectFit
                    source: trayItemDelegate.modelData.icon
                    sourceSize.width: width
                    sourceSize.height: height
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && trayItemDelegate.modelData.hasMenu) {
                            trayItemDelegate.modelData.display(trayItemDelegate, trayItemDelegate.width / 2, trayItemDelegate.height);
                        } else {
                            trayItemDelegate.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
