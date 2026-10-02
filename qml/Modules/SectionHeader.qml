import QtQuick

// Small header used inside the detail panels: back chevron + title
// (+ optional power switch, optional refresh button).
Item {
    id: header

    height: 30
    property string title: ""
    property bool showRefresh: false
    property bool showSwitch: false
    property bool checked: false

    signal closed()
    signal refreshed()
    signal toggled(bool on)

    Text {
        id: backChevron

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅁" // md-chevron_left
        color: backHover.containsMouse ? "#ffffff" : "#a0a0a5"
        font.pixelSize: 14
    }

    MouseArea {
        id: backHover

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 26
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: header.closed()
    }

    Text {
        anchors.left: backChevron.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        color: "#f2f2f2"
        font.pixelSize: 13
        font.bold: true
    }

    Rectangle {
        id: switchBox

        visible: header.showSwitch
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 18
        radius: height / 2
        color: header.checked ? "#3f8fe0" : "#2c2c30"

        Rectangle {
            width: 14
            height: 14
            radius: width / 2
            color: "#e8e8e8"
            x: header.checked ? switchBox.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter

            Behavior on x {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: header.toggled(!header.checked)
        }
    }

    Rectangle {
        id: refreshBox

        visible: header.showRefresh
        anchors.right: header.showSwitch ? switchBox.left : parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 6
        color: refreshHover.containsMouse ? "#2e2e33" : "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰑐" // md-refresh
            color: refreshHover.containsMouse ? "#ffffff" : "#a0a0a5"
            font.pixelSize: 13
        }

        MouseArea {
            id: refreshHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: header.refreshed()
        }
    }
}